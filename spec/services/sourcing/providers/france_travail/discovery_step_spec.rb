require "rails_helper"

RSpec.describe Sourcing::Providers::FranceTravail::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  describe "with a stub crawler" do
    let(:stub_urls) do
      [
        "https://candidat.francetravail.fr/offres/recherche/detail/AAA111",
        "https://candidat.francetravail.fr/offres/recherche/detail/BBB222",
      ]
    end
    let(:crawler) { ->(input:, playwright_runtime:) { { discovered_urls: stub_urls } } }

    subject(:step) { described_class.new(crawler: crawler) }

    it "delegates crawl_every_pages to the injected crawler" do
      runtime = step.initialize_playwright(input: { source: "france_travail", keyword: "ruby" })
      result  = step.crawl_every_pages(input: { keyword: "ruby" }, playwright_runtime: runtime)

      expect(result[:discovered_urls]).to eq(stub_urls)
    end

    it "returns unique URLs" do
      duplicate_crawler = ->(input:, playwright_runtime:) {
        { discovered_urls: stub_urls + stub_urls }
      }
      step = described_class.new(crawler: duplicate_crawler)
      runtime = step.initialize_playwright(input: {})
      result = step.crawl_every_pages(input: {}, playwright_runtime: runtime)
      expect(result[:discovered_urls].size).to eq(2)
    end
  end

  describe "#close_playwright" do
    it "is a no-op for crawler mode" do
      expect { step.close_playwright(playwright_runtime: { mode: :crawler }) }.not_to raise_error
    end
  end
end
