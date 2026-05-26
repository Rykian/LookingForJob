require "rails_helper"

RSpec.describe Sourcing::Providers::Indeed::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  describe "with stub crawler" do
    let(:stub_urls) do
      [
        "https://fr.indeed.com/viewjob?jk=abc123def456",
        "https://fr.indeed.com/viewjob?jk=fed654cba321",
      ]
    end

    let(:crawler) do
      ->(input:, runtime:, page:) { { discovered_urls: stub_urls, has_next_page: false } }
    end

    subject(:step) { described_class.new(crawler: crawler) }

    it "returns discovered URLs from the crawler stub" do
      result = step.call(source: "indeed", keyword: "ruby", work_mode: nil, force: false)
      expect(result[:discovered_urls]).to match_array(stub_urls)
    end
  end

  describe "#send(:build_search_url)" do
    it "builds a page-1 URL with only the keyword" do
      url = step.send(:build_search_url, keyword: "ruby developer", work_mode: nil, page: 1)
      expect(url).to eq("https://fr.indeed.com/jobs?q=ruby+developer")
    end

    it "adds start offset for pages beyond 1" do
      url = step.send(:build_search_url, keyword: "ruby", work_mode: nil, page: 3)
      expect(url).to include("start=20")
    end

    it "adds the remote sc filter for work_mode=remote" do
      url = step.send(:build_search_url, keyword: "ruby", work_mode: "remote", page: 1)
      expect(url).to include("sc=#{CGI.escape("0kf:attr(DSQF7);")}")
    end

    it "adds the hybrid sc filter for work_mode=hybrid" do
      url = step.send(:build_search_url, keyword: "ruby", work_mode: "hybrid", page: 1)
      expect(url).to include("sc=#{CGI.escape("0kf:attr(PAXZC);")}")
    end

    it "raises for unsupported work_mode=on-site" do
      expect { step.send(:build_search_url, keyword: "ruby", work_mode: "on-site", page: 1) }
        .to raise_error(ArgumentError, /on-site/)
    end

    it "raises for arbitrary work_mode values" do
      expect { step.send(:build_search_url, keyword: "ruby", work_mode: "bogus", page: 1) }
        .to raise_error(ArgumentError, /Unsupported work_mode/)
    end
  end

  describe "#send(:canonical_viewjob_url)" do
    it "builds a canonical viewjob URL from a jk id" do
      expect(step.send(:canonical_viewjob_url, "abc123")).to eq("https://fr.indeed.com/viewjob?jk=abc123")
    end
  end
end
