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
    let(:crawler) { ->(input:, runtime:) { { discovered_urls: stub_urls } } }

    subject(:step) { described_class.new(crawler: crawler) }

    it "delegates crawl_every_pages to the injected crawler" do
      runtime = step.setup(input: { source: "france_travail", keyword: "ruby" })
      result  = step.crawl_every_pages(input: { keyword: "ruby" }, runtime: runtime)

      expect(result[:discovered_urls]).to eq(stub_urls)
    end

    it "returns unique URLs" do
      duplicate_crawler = ->(input:, runtime:) {
        { discovered_urls: stub_urls + stub_urls }
      }
      step = described_class.new(crawler: duplicate_crawler)
      runtime = step.setup(input: {})
      result = step.crawl_every_pages(input: {}, runtime: runtime)
      expect(result[:discovered_urls].size).to eq(2)
    end
  end

  describe "#teardown" do
    it "is a no-op for crawler mode" do
      expect { step.teardown(runtime: { mode: :crawler }) }.not_to raise_error
    end
  end

  describe "empty search results" do
    it "returns empty array when no results found" do
      empty_crawler = ->(input:, runtime:) do
        # Simulate France Travail returning no results (e.g., searching for "Elixir")
        { discovered_urls: [] }
      end
      step = described_class.new(crawler: empty_crawler)
      runtime = step.setup(input: {})
      result = step.crawl_every_pages(input: {}, runtime: runtime)

      expect(result[:discovered_urls]).to eq([])
    end
  end
end
