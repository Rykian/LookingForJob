require "rails_helper"

RSpec.describe Sourcing::Providers::FreeWork::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_json) { { "id" => 1, "title" => "Backend Engineer" }.to_json }
    subject(:step) { described_class.new(fetcher: ->(**) { stub_json }) }

    it "calls the fetcher with the provided URL" do
      result = step.call(url: "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/x")
      expect(result).to eq(stub_json)
    end
  end

  describe "#fetch_page with stubbed connection" do
    let(:url) { "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/developpeur-ruby-8" }
    let(:api_url) { "https://www.free-work.com/api/job_postings/developpeur-ruby-8" }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:connection) { Faraday.new { |b| b.adapter(:test, stubs) } }
    subject(:step) { described_class.new(connection: connection) }

    it "fetches the API payload for the slug extracted from the public URL" do
      body = { "id" => 621_936, "title" => "Développeur Ruby On Rails (H/F)" }.to_json
      stubs.get(api_url) { [200, {}, body] }

      expect(step.call(url: url)).to eq(body)
    end

    it "raises OfferGoneError on HTTP 404" do
      stubs.get(api_url) { [404, {}, "{}"] }

      expect { step.call(url: url) }.to raise_error(Sourcing::OfferGoneError, /HTTP 404/)
    end

    it "raises a loud error on non-2xx, non-404 HTTP statuses" do
      stubs.get(api_url) { [503, {}, "boom"] }

      expect { step.call(url: url) }.to raise_error(StandardError, /HTTP 503/)
    end

    it "raises a loud error when the body is not valid JSON" do
      stubs.get(api_url) { [200, {}, "<html>not json</html>"] }

      expect { step.call(url: url) }.to raise_error(StandardError, /not valid JSON/)
    end

    it "raises a loud error when the payload is not a job posting" do
      stubs.get(api_url) { [200, {}, { "title" => "" }.to_json] }

      expect { step.call(url: url) }.to raise_error(StandardError, /not a job posting payload/)
    end

    it "raises a loud error when the URL has no job-mission slug" do
      expect { step.call(url: "https://www.free-work.com/fr/tech-it/jobs") }
        .to raise_error(StandardError, /cannot extract slug/)
    end
  end
end
