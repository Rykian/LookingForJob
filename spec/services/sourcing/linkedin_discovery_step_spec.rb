require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::DiscoveryStep do
  let(:page_size) { described_class::PAGE_SIZE }

  def make_urls(count)
    count.times.map { |i| "https://example.com/jobs/#{i}" }
  end

  it "strips query params and fragments from all discovered URLs" do
    dirty_url = "https://www.linkedin.com/jobs/view/1234567/?refId=abc&trackingId=xyz&position=1#top"
    crawler = ->(_input) { { discovered_urls: [ dirty_url ], has_next_page: false } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote"
    )

    expect(result[:discovered_urls]).to eq([ "https://www.linkedin.com/jobs/view/1234567/" ])
  end

  it "deduplicates URLs across all pages" do
    call_count = 0
    crawler = lambda do |_input|
      call_count += 1
      case call_count
      when 1 then { discovered_urls: [ "https://example.com/jobs/1", "https://example.com/jobs/1" ], has_next_page: true }
      else        { discovered_urls: [ "https://example.com/jobs/1" ], has_next_page: false }
      end
    end

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote"
    )

    expect(result[:discovered_urls]).to eq([ "https://example.com/jobs/1" ])
  end

  it "crawls subsequent pages when has_next_page is true" do
    call_count = 0
    crawler = lambda do |input|
      call_count += 1
      case call_count
      when 1 then { discovered_urls: [ "https://example.com/jobs/page1" ], has_next_page: true }
      when 2 then { discovered_urls: [ "https://example.com/jobs/page2" ], has_next_page: true }
      else        { discovered_urls: [], has_next_page: false }
      end
    end

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote"
    )

    expect(call_count).to eq(3)
    expect(result[:discovered_urls]).to match_array([
      "https://example.com/jobs/page1",
      "https://example.com/jobs/page2",
    ])
  end

  it "stops after the first empty page" do
    call_count = 0
    crawler = lambda do |_input|
      call_count += 1
      { discovered_urls: [], has_next_page: false }
    end

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote"
    )

    expect(call_count).to eq(1)
    expect(result[:discovered_urls]).to be_empty
  end

  it "stops after MAX_PAGES regardless of has_next_page" do
    crawler = ->(input) { { discovered_urls: [ "https://example.com/jobs/#{input[:page]}" ], has_next_page: true } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote"
    )

    expect(result[:discovered_urls].size).to eq(described_class::MAX_PAGES)
  end

  it "builds search url with f_WT when work_mode is present" do
    step = described_class.new(crawler: ->(_input) { { discovered_urls: [], has_next_page: false } })

    url = step.send(:build_search_url, keyword: "Ruby", work_mode: "remote", page: 1)

    expect(url).to include("keywords=Ruby")
    expect(url).to include("start=0")
    expect(url).to include("f_WT=2")
  end

  it "builds search url without f_WT when work_mode is blank" do
    step = described_class.new(crawler: ->(_input) { { discovered_urls: [], has_next_page: false } })

    url = step.send(:build_search_url, keyword: "Ruby", work_mode: "", page: 2)

    expect(url).to include("keywords=Ruby")
    expect(url).to include("start=25")
    expect(url).not_to include("f_WT=")
  end
end
