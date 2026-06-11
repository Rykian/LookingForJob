require "rails_helper"

RSpec.describe Sourcing::Providers::FreeWork::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  it "advertises work-mode filtering (remoteMode filters server-side)" do
    expect(step.supports_work_mode_filter?).to be(true)
  end

  describe "#build_search_url" do
    it "adds the searchKeywords param when a keyword is given" do
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: nil, page: 1))
        .to eq("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=ruby")
    end

    it "URL-encodes the keyword" do
      expect(step.send(:build_search_url, keyword: "ruby on rails", work_mode: nil, page: 1))
        .to eq("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=ruby+on+rails")
    end

    it "maps work modes to remoteMode" do
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: "remote", page: 1))
        .to include("remoteMode=full")
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: "hybrid", page: 1))
        .to include("remoteMode=partial")
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: "on-site", page: 1))
        .to include("remoteMode=none")
    end

    it "omits remoteMode for unknown or nil work modes" do
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: nil, page: 1))
        .not_to include("remoteMode")
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: "anything", page: 1))
        .not_to include("remoteMode")
    end

    it "adds the page param only past page 1" do
      expect(step.send(:build_search_url, keyword: "ruby", work_mode: nil, page: 2))
        .to eq("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=ruby&page=2")
    end

    it "omits searchKeywords when no keyword is given" do
      expect(step.send(:build_search_url, keyword: nil, work_mode: nil, page: 1))
        .to eq("https://www.free-work.com/api/job_postings?itemsPerPage=30")
      expect(step.send(:build_search_url, keyword: "", work_mode: nil, page: 1))
        .to eq("https://www.free-work.com/api/job_postings?itemsPerPage=30")
    end
  end

  describe "#offer_url" do
    it "builds the public detail URL from category slug and offer slug" do
      member = { "slug" => "developpeur-ruby-8", "job" => { "nameForContributionSlug" => "developpeur-ruby" } }
      expect(step.send(:offer_url, member))
        .to eq("https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/developpeur-ruby-8")
    end

    it "falls back to a generic category slug when missing" do
      member = { "slug" => "developpeur-ruby-8" }
      expect(step.send(:offer_url, member))
        .to eq("https://www.free-work.com/fr/tech-it/consultant-fonctionnel/job-mission/developpeur-ruby-8")
    end

    it "returns nil for empty or missing slugs" do
      expect(step.send(:offer_url, { "slug" => "" })).to be_nil
      expect(step.send(:offer_url, {})).to be_nil
    end
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/a",
        "https://www.free-work.com/fr/tech-it/developpeur-java/job-mission/b",
      ]
    end

    let(:crawler) do
      lambda do |input:, runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from the crawler stub" do
      result = step.call(source: "free_work", keyword: "ruby", work_mode: nil, force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "#crawl_page with stubbed connection" do
    # Builds a minimal hydra collection like the API Platform endpoint returns.
    def build_collection(members:, total:, next_page: nil)
      view = { "@id" => "/job_postings?page=1" }
      view["hydra:next"] = next_page if next_page

      {
        "hydra:totalItems" => total,
        "hydra:member" => members,
        "hydra:view" => view,
      }.to_json
    end

    def member(slug, category: "developpeur-ruby")
      { "slug" => slug, "job" => { "nameForContributionSlug" => category } }
    end

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }

    let(:connection) do
      Faraday.new do |b|
        b.adapter(:test, stubs) do |stub|
          stub.get("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=ruby") do
            [200, {}, build_collection(
              members: [member("a"), member("b")],
              total: 3,
              next_page: "/job_postings?searchKeywords=ruby&page=2"
            ),]
          end
          stub.get("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=ruby&page=2") do
            [200, {}, build_collection(members: [member("c")], total: 3)]
          end
        end
      end
    end

    subject(:step) { described_class.new(connection: connection) }

    it "extracts member slugs into offer URLs and signals has_next_page from hydra:view" do
      page1 = step.crawl_page(input: { keyword: "ruby", work_mode: nil }, runtime: {}, page: 1)
      expect(page1[:discovered_urls]).to eq([
        "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/a",
        "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/b",
      ])
      expect(page1[:has_next_page]).to be(true)

      page2 = step.crawl_page(input: { keyword: "ruby", work_mode: nil }, runtime: {}, page: 2)
      expect(page2[:discovered_urls]).to eq([
        "https://www.free-work.com/fr/tech-it/developpeur-ruby/job-mission/c",
      ])
      expect(page2[:has_next_page]).to be(false)
    end

    it "stops at MAX_PAGES" do
      expect(step.crawl_page(input: { keyword: "ruby", work_mode: nil }, runtime: {}, page: described_class::MAX_PAGES + 1))
        .to eq(discovered_urls: [], has_next_page: false)
    end

    it "raises with context when the HTTP request fails" do
      stubs.get("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=java") do
        [500, {}, "boom"]
      end

      expect { step.crawl_page(input: { keyword: "java", work_mode: nil }, runtime: {}, page: 1) }
        .to raise_error(StandardError, /FreeWork crawl_page failed/)
    end

    it "raises with context when hydra:member is missing" do
      stubs.get("https://www.free-work.com/api/job_postings?itemsPerPage=30&searchKeywords=scala") do
        [200, {}, { "unexpected" => true }.to_json]
      end

      expect { step.crawl_page(input: { keyword: "scala", work_mode: nil }, runtime: {}, page: 1) }
        .to raise_error(StandardError, /no hydra:member/)
    end
  end
end
