require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::FetchStep do
  subject(:step) { described_class.new(connection: fake_connection) }

  let(:fake_connection) { instance_double(Faraday::Connection) }
  let(:job_url) { "https://www.linkedin.com/jobs/view/4374109608/" }

  before { allow(step).to receive(:throttle!) }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "#call" do
    let(:valid_html) do
      %(<section class="top-card-layout"><h2 class="top-card-layout__title">Backend Engineer</h2></section>)
    end

    it "returns HTML when the job page contains the title marker" do
      response = instance_double(Faraday::Response, status: 200, body: valid_html)
      allow(fake_connection).to receive(:get).with(/jobPosting\/4374109608/).and_return(response)

      expect(step.call(url: job_url)).to eq(valid_html)
    end

    it "raises FetchContentError when title marker is missing" do
      response = instance_double(Faraday::Response, status: 200, body: "<html><body>nothing</body></html>")
      allow(fake_connection).to receive(:get).and_return(response)

      expect { step.call(url: job_url) }.to raise_error(
        Sourcing::Providers::Linkedin::FetchContentError, /title marker/
      )
    end

    it "raises FetchContentError on HTTP 404 (job removed)" do
      response = instance_double(Faraday::Response, status: 404, body: "")
      allow(fake_connection).to receive(:get).and_return(response)

      expect { step.call(url: job_url) }.to raise_error(
        Sourcing::Providers::Linkedin::FetchContentError, /removed or unavailable/
      )
    end

    it "raises a loud error on HTTP 429 (rate limit)" do
      response = instance_double(Faraday::Response, status: 429, body: "")
      allow(fake_connection).to receive(:get).and_return(response)

      expect { step.call(url: job_url) }.to raise_error(/rate-limited or blocked/)
    end

    it "raises FetchContentError on shell HTML" do
      response = instance_double(Faraday::Response, status: 200, body: "<html><body></body></html>")
      allow(fake_connection).to receive(:get).and_return(response)

      expect { step.call(url: job_url) }.to raise_error(/shell_html/)
    end

    it "raises FetchContentError when the URL has no extractable job id" do
      expect {
        step.call(url: "https://www.linkedin.com/jobs/view/")
      }.to raise_error(Sourcing::Providers::Linkedin::FetchContentError, /could not extract job id/)
    end

    it "throttles before each request" do
      response = instance_double(Faraday::Response, status: 200, body: valid_html)
      allow(fake_connection).to receive(:get).and_return(response)

      step.call(url: job_url)

      expect(step).to have_received(:throttle!).once
    end
  end
end
