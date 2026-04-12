require "rails_helper"

RSpec.describe Sourcing::Providers::Apec::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.apec.fr/candidat/recherche-emploi.html/emploi/detail-offre/178415402W",
        "https://www.apec.fr/candidat/recherche-emploi.html/emploi/detail-offre/178367863W",
      ]
    end

    let(:crawler) do
      lambda do |input:, playwright_runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from crawler" do
      result = step.call(source: "apec", keyword: "ruby", work_mode: "remote", force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "search URL mapping" do
    it "maps hybrid to the two validated telework filters" do
      url = step.send(:build_search_url, keyword: "ruby", work_mode: "hybrid", page: 1)

      expect(url).to include("motsCles=ruby")
      expect(url.scan("typesTeletravail=20765").size).to eq(1)
      expect(url.scan("typesTeletravail=20766").size).to eq(1)
      expect(url).to include("page=0")
    end

    it "maps remote to the total-remote filter" do
      url = step.send(:build_search_url, keyword: "ruby", work_mode: "remote", page: 2)

      expect(url).to include("typesTeletravail=20767")
      expect(url).to include("page=1")
    end

    it "fails loudly for on-site because no stable on-site filter was validated" do
      expect do
        step.send(:build_search_url, keyword: "ruby", work_mode: "on-site", page: 1)
      end.to raise_error(ArgumentError, /on-site-only filter/)
    end
  end
end
