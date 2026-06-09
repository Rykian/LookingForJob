require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  it "does not advertise work-mode filtering (location is captured per-offer in analyze)" do
    expect(step.supports_work_mode_filter?).to be(false)
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.welovedevs.com/app/job/backend-engineer-wm-datadome",
        "https://www.welovedevs.com/app/job/frontend-developer-acme",
      ]
    end

    let(:crawler) do
      lambda do |input:, runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from the crawler stub" do
      result = step.call(source: "welovedevs", keyword: "ruby", work_mode: nil, force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "#build_search_url" do
    it "encodes the keyword into the Algolia search query param" do
      expect(step.send(:build_search_url, "ruby on rails"))
        .to eq("https://www.welovedevs.com/app/jobs?query=ruby+on+rails")
    end

    it "returns the bare jobs URL when no keyword is given" do
      expect(step.send(:build_search_url, "")).to eq("https://www.welovedevs.com/app/jobs")
      expect(step.send(:build_search_url, nil)).to eq("https://www.welovedevs.com/app/jobs")
    end
  end

  describe "#offer_url" do
    it "builds the canonical detail URL from an Algolia seoAlias slug" do
      expect(step.send(:offer_url, "backend-engineer-wm-datadome"))
        .to eq("https://www.welovedevs.com/app/job/backend-engineer-wm-datadome")
    end
  end

  describe "#collect_slugs" do
    let(:algolia_body) do
      {
        results: [
          { hits: [
            { "seoAlias" => "backend-engineer-wm-datadome", "title" => "Backend Engineer" },
            { "seoAlias" => "frontend-developer-acme", "title" => "Frontend Developer" },
            { "title" => "No slug here" },
          ] },
        ],
      }.to_json
    end

    let(:response) do
      instance_double("Playwright::Response", url: "https://g9s2j15g1n-dsn.algolia.net/1/indexes/*/queries", body: algolia_body)
    end

    it "collects non-empty seoAlias slugs from an Algolia response" do
      slugs = Set.new
      step.send(:collect_slugs, response, slugs)
      expect(slugs.to_a).to match_array(%w[backend-engineer-wm-datadome frontend-developer-acme])
    end

    it "ignores non-Algolia responses" do
      other = instance_double("Playwright::Response", url: "https://www.welovedevs.com/_next/data.json", body: algolia_body)
      slugs = Set.new
      step.send(:collect_slugs, other, slugs)
      expect(slugs).to be_empty
    end

    it "does not raise on non-JSON bodies" do
      bad = instance_double("Playwright::Response", url: "https://algolia.net/x", body: "<html>not json</html>")
      slugs = Set.new
      expect { step.send(:collect_slugs, bad, slugs) }.not_to raise_error
      expect(slugs).to be_empty
    end
  end
end
