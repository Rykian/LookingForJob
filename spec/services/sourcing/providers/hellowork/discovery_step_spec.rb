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
end
