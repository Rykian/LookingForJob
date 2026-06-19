require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  it "does not advertise work-mode filtering (location is captured per-offer in analyze)" do
    expect(step.supports_work_mode_filter?).to be(false)
  end

  # Minimal AlgoliaClient stand-in: returns canned search pages keyed by Algolia page index.
  def fake_client(pages)
    client = instance_double(Sourcing::Providers::Welovedevs::AlgoliaClient)
    allow(client).to receive(:search) do |query:, page:, hits_per_page:|
      pages.fetch(page, { "hits" => [], "nbHits" => 0, "nbPages" => pages.size })
    end
    client
  end

  describe "#call" do
    let(:page0) do
      {
        "nbHits" => 3,
        "nbPages" => 2,
        "hits" => [
          { "objectID" => "greenhouse+5967999002", "type" => "company_job" },
          { "objectID" => "-M9J77TzRX3uWXM7lQJ7", "type" => "company_job" },
          { "objectID" => "iEfXYJ", "type" => "spontaneous_application" }, # skipped
        ],
      }
    end

    let(:page1) do
      {
        "nbHits" => 3,
        "nbPages" => 2,
        "hits" => [
          { "objectID" => "-O24k59jt-evRg", "type" => "company_job" },
          { "type" => "company_job" }, # no objectID, skipped
        ],
      }
    end

    subject(:step) { described_class.new(client: fake_client(0 => page0, 1 => page1)) }

    it "paginates all Algolia pages and builds jobId URLs, encoding the objectID" do
      result = step.call(source: "welovedevs", keyword: "ruby", work_mode: nil, page: 1)

      expect(result[:discovered_urls]).to eq([
        "https://www.welovedevs.com/app/jobs?jobId=greenhouse%2B5967999002",
        "https://www.welovedevs.com/app/jobs?jobId=-M9J77TzRX3uWXM7lQJ7",
        "https://www.welovedevs.com/app/jobs?jobId=-O24k59jt-evRg",
      ])
    end

    it "skips spontaneous-application entries and hits without an objectID" do
      urls = step.call(source: "welovedevs", keyword: "ruby", work_mode: nil, page: 1)[:discovered_urls]
      expect(urls).not_to include(a_string_matching(/jobId=iEfXYJ/))
      expect(urls.size).to eq(3)
    end
  end

  describe "#crawl_page pagination flag" do
    it "reports has_next_page until the last Algolia page" do
      client = fake_client({})
      allow(client).to receive(:search).and_return({ "hits" => [], "nbHits" => 0, "nbPages" => 3 })
      step = described_class.new(client: client)

      runtime = step.setup(input: {})
      expect(step.crawl_page(input: { keyword: "x" }, runtime: runtime, page: 1)[:has_next_page]).to be(true)
      expect(step.crawl_page(input: { keyword: "x" }, runtime: runtime, page: 3)[:has_next_page]).to be(false)
    end
  end
end
