require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::DiscoveryStep do
  let(:page_size) { described_class::PAGE_SIZE }

  def make_urls(count)
    count.times.map { |i| "https://example.com/jobs/#{i}" }
  end

  it "strips query params and fragments from discovered URLs" do
    dirty_url = "https://www.linkedin.com/jobs/view/1234567/?refId=abc&trackingId=xyz&position=1#top"
    crawler = ->(_input) { { discovered_urls: [ dirty_url ] } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 1
    )

    expect(result[:discovered_urls]).to eq([ "https://www.linkedin.com/jobs/view/1234567/" ])
  end

  it "deduplicates URLs in the result" do
    crawler = ->(_input) { { discovered_urls: [ "https://example.com/jobs/1", "https://example.com/jobs/1" ] } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 1
    )

    expect(result[:discovered_urls]).to eq([ "https://example.com/jobs/1" ])
  end

  it "sets has_next_page and next_job_data when a full page is returned" do
    crawler = ->(_input) { { discovered_urls: make_urls(page_size) } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 1
    )

    expect(result[:has_next_page]).to be(true)
    expect(result[:next_job_data]).to eq(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 2
    )
  end

  it "stops pagination when a partial page is returned" do
    crawler = ->(_input) { { discovered_urls: make_urls(page_size - 1) } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 3
    )

    expect(result[:has_next_page]).to be(false)
    expect(result[:next_job_data]).to be_nil
  end

  it "stops pagination when the page is empty" do
    crawler = ->(_input) { { discovered_urls: [] } }

    result = described_class.new(crawler: crawler).call(
      source: "linkedin", keyword: "ruby", work_mode: "remote", page: 2
    )

    expect(result[:has_next_page]).to be(false)
    expect(result[:next_job_data]).to be_nil
  end
end
