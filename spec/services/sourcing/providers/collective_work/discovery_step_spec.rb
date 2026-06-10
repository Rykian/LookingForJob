require "rails_helper"

RSpec.describe Sourcing::Providers::CollectiveWork::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  it "does not advertise work-mode filtering (the SSR payload ignores it)" do
    expect(step.supports_work_mode_filter?).to be(false)
  end

  describe "#build_search_url" do
    it "adds the search param when a keyword is given" do
      expect(step.send(:build_search_url, keyword: "ruby", page: 1))
        .to eq("https://www.collective.work/jobs/fr?search=ruby")
    end

    it "URL-encodes the keyword" do
      expect(step.send(:build_search_url, keyword: "ruby on rails", page: 1))
        .to eq("https://www.collective.work/jobs/fr?search=ruby+on+rails")
    end

    it "adds the page param only past page 1" do
      expect(step.send(:build_search_url, keyword: "ruby", page: 2))
        .to eq("https://www.collective.work/jobs/fr?search=ruby&page=2")
    end

    it "returns the bare listing URL when no keyword and page 1" do
      expect(step.send(:build_search_url, keyword: nil, page: 1))
        .to eq("https://www.collective.work/jobs/fr")
      expect(step.send(:build_search_url, keyword: "", page: 1))
        .to eq("https://www.collective.work/jobs/fr")
    end
  end

  describe "#offer_url" do
    it "builds the canonical detail URL from a slug" do
      expect(step.send(:offer_url, "senior-backend-engineer-abcd"))
        .to eq("https://www.collective.work/jobs/fr/senior-backend-engineer-abcd")
    end

    it "returns nil for empty or non-string slugs" do
      expect(step.send(:offer_url, "")).to be_nil
      expect(step.send(:offer_url, nil)).to be_nil
    end
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://www.collective.work/jobs/fr/backend-engineer-abcd",
        "https://www.collective.work/jobs/fr/frontend-developer-wxyz",
      ]
    end

    let(:crawler) do
      lambda do |input:, runtime:, page:|
        { discovered_urls: stub_urls, has_next_page: false }
      end
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from the crawler stub" do
      result = step.call(source: "collective_work", keyword: "ruby", work_mode: nil, force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "#crawl_page with stubbed connection" do
    # Builds a minimal HTML doc with an embedded __NEXT_DATA__ search payload.
    def build_listing_html(projects:, total:, from:)
      payload = {
        "props" => {
          "pageProps" => {
            "dehydratedState" => {
              "queries" => [
                {
                  "queryKey" => ["PublicPages_SearchJobs", { "data" => { "query" => "" } }],
                  "state" => {
                    "data" => {
                      "results" => {
                        "projects" => projects,
                        "pagination" => { "from" => from, "total" => total },
                      },
                    },
                  },
                },
              ],
            },
          },
        },
      }
      %(<html><body><script id="__NEXT_DATA__" type="application/json">#{payload.to_json}</script></body></html>)
    end

    let(:connection) do
      Faraday.new do |b|
        b.adapter(:test, stubs) do |stub|
          stub.get("https://www.collective.work/jobs/fr") do
            [200, {}, build_listing_html(
              projects: [{ "slug" => "a" }, { "slug" => "b" }],
              total: 5,
              from: 0
            ),]
          end
          stub.get("https://www.collective.work/jobs/fr?page=2") do
            [200, {}, build_listing_html(
              projects: [{ "slug" => "c" }, { "slug" => "d" }, { "slug" => "e" }],
              total: 5,
              from: 2
            ),]
          end
          stub.get("https://www.collective.work/jobs/fr?page=3") do
            [200, {}, build_listing_html(projects: [], total: 5, from: 5)]
          end
        end
      end
    end

    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    subject(:step) { described_class.new(connection: connection) }

    it "extracts slugs into offer URLs and signals has_next_page until exhausted" do
      page1 = step.crawl_page(input: { keyword: nil }, runtime: {}, page: 1)
      expect(page1[:discovered_urls]).to eq([
        "https://www.collective.work/jobs/fr/a",
        "https://www.collective.work/jobs/fr/b",
      ])
      expect(page1[:has_next_page]).to be(true)

      page2 = step.crawl_page(input: { keyword: nil }, runtime: {}, page: 2)
      expect(page2[:discovered_urls]).to eq([
        "https://www.collective.work/jobs/fr/c",
        "https://www.collective.work/jobs/fr/d",
        "https://www.collective.work/jobs/fr/e",
      ])
      expect(page2[:has_next_page]).to be(false)

      page3 = step.crawl_page(input: { keyword: nil }, runtime: {}, page: 3)
      expect(page3[:discovered_urls]).to be_empty
      expect(page3[:has_next_page]).to be(false)
    end

    it "stops at MAX_PAGES" do
      expect(step.crawl_page(input: { keyword: nil }, runtime: {}, page: described_class::MAX_PAGES + 1))
        .to eq(discovered_urls: [], has_next_page: false)
    end

    it "raises with context when the HTTP request fails" do
      stubs.get("https://www.collective.work/jobs/fr?search=ruby") do
        [500, {}, "boom"]
      end

      expect { step.crawl_page(input: { keyword: "ruby" }, runtime: {}, page: 1) }
        .to raise_error(StandardError, /CollectiveWork crawl_page failed/)
    end
  end
end
