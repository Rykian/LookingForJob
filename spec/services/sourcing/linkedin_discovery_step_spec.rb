require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::DiscoveryStep do
  it "returns normalized discovery payload with next job data" do
    crawler = lambda do |_input|
      {
        discovered_urls: ["https://example.com/jobs/1", "https://example.com/jobs/1"],
        has_next_page: true
      }
    end

    result = described_class.new(crawler: crawler).call(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      page: 1
    )

    expect(result[:discovered_urls]).to eq(["https://example.com/jobs/1"])
    expect(result[:has_next_page]).to be(true)
    expect(result[:next_job_data]).to eq(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      page: 2
    )
  end
end
