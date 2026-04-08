require "rails_helper"

RSpec.describe Sourcing::Providers::Cadremploi::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.cadremploi.fr/emploi/detail_offre?offreId=100000000000000001",
        "https://www.cadremploi.fr/emploi/detail_offre?offreId=100000000000000002",
      ]
    end

    let(:crawler) do
      lambda do |input:, playwright_runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from the crawler stub" do
      result = step.call(source: "cadremploi", keyword: "ruby", work_mode: nil, force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end
end
