require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::FetchStep do
  it "returns fetched html from injected fetcher" do
    fetcher = ->(input) { "<html>#{input.fetch(:url)}</html>" }

    html = described_class.new(fetcher: fetcher).call(
      source: "linkedin",
      url: "https://example.com/jobs/1",
      url_hash: "hash"
    )

    expect(html).to include("https://example.com/jobs/1")
  end
end
