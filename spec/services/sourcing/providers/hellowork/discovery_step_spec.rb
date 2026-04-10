require "rails_helper"

RSpec.describe Sourcing::Providers::Hellowork::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  it "disables work_mode filter support" do
    expect(step.supports_work_mode_filter?).to eq(false)
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.hellowork.com/fr-fr/emplois/77465108.html",
        "https://www.hellowork.com/fr-fr/emplois/77297135.html",
      ]
    end

    let(:crawler) do
      lambda do |input:, playwright_runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from crawler" do
      result = step.call(source: "hellowork", keyword: "ruby", work_mode: "remote", force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "#crawl_page" do
    let(:context) { instance_double("PlaywrightContext") }
    let(:page_obj) { instance_double("PlaywrightPage") }
    let(:runtime) { { context: context } }
    let(:url) { "https://www.hellowork.com/fr-fr/emploi/recherche.html?k=ruby&p=3" }

    before do
      allow(context).to receive(:new_page).and_return(page_obj)
      allow(page_obj).to receive(:goto)
      allow(page_obj).to receive(:close)
      allow(step).to receive(:build_search_url).and_return(url)
      allow(step).to receive(:blocked_page?).and_return(false)
    end

    it "stops pagination gracefully when a later page has no job links" do
      allow(step).to receive(:wait_for_any_selector).and_return(nil)

      result = step.crawl_page(input: { keyword: "ruby" }, playwright_runtime: runtime, page: 3)

      expect(result).to eq(discovered_urls: [], has_next_page: false)
    end

    it "still fails on first page when no job links are found" do
      allow(step).to receive(:wait_for_any_selector).and_return(nil)

      expect do
        step.crawl_page(input: { keyword: "ruby" }, playwright_runtime: runtime, page: 1)
      end.to raise_error(RuntimeError, /found no job links/)
    end
  end
end
