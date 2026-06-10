require "rails_helper"

RSpec.describe Sourcing::Providers::CollectiveWork::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) { "<html><body><h1>Backend Engineer</h1></body></html>" }
    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "calls the fetcher with the provided URL" do
      result = step.call(url: "https://www.collective.work/jobs/fr/x")
      expect(result).to eq(stub_html)
    end
  end

  describe "#fetch_page with stubbed connection" do
    def build_html(project:)
      payload = { "props" => { "pageProps" => { "project" => project } } }
      %(<html><body><script id="__NEXT_DATA__" type="application/json">#{payload.to_json}</script></body></html>)
    end

    let(:url) { "https://www.collective.work/jobs/fr/senior-backend-abcd" }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:connection) { Faraday.new { |b| b.adapter(:test, stubs) } }
    subject(:step) { described_class.new(connection: connection) }

    it "returns the HTML when the project payload is present" do
      html = build_html(project: { "id" => "1", "name" => "Senior" })
      stubs.get(url) { [200, {}, html] }

      expect(step.call(url: url)).to eq(html)
    end

    it "raises OfferGoneError on HTTP 404" do
      stubs.get(url) { [404, {}, "<html><body>Not found</body></html>"] }

      expect { step.call(url: url) }.to raise_error(Sourcing::OfferGoneError, /HTTP 404/)
    end

    it "raises OfferGoneError when project is null" do
      stubs.get(url) { [200, {}, build_html(project: nil)] }

      expect { step.call(url: url) }.to raise_error(Sourcing::OfferGoneError, /no project payload/)
    end

    it "raises a loud error on missing __NEXT_DATA__ (selector drift)" do
      stubs.get(url) { [200, {}, "<html><body><h1>Job</h1></body></html>"] }

      expect { step.call(url: url) }.to raise_error(StandardError, /without __NEXT_DATA__/)
    end

    it "raises a loud error on non-2xx, non-404 HTTP statuses" do
      stubs.get(url) { [503, {}, "boom"] }

      expect { step.call(url: url) }.to raise_error(StandardError, /HTTP 503/)
    end

    it "raises on shell HTML" do
      stubs.get(url) { [200, {}, "<html><head></head><body></body></html>"] }

      expect { step.call(url: url) }.to raise_error(StandardError, /shell_html/)
    end
  end
end
