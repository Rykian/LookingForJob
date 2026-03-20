require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::AnalyzeStep do
  subject(:step) { described_class.new }

  it "extracts structured fields from linkedin-like html" do
    html = <<~HTML
      <!doctype html>
      <html>
        <head><title>Senior Backend Engineer | Acme | LinkedIn</title></head>
        <body>
          <div class="job-details-jobs-unified-top-card__job-title"><h1>Backend Engineer</h1></div>
          <div class="job-details-jobs-unified-top-card__company-name"><a>Acme</a></div>
          <div data-testid="expandable-text-box"><p>CDI, hybrid, 2 days remote.</p></div>
          <time datetime="2026-03-20T09:00:00Z"></time>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Backend Engineer")
    expect(result[:company]).to eq("Acme")
    expect(result[:remote]).to eq("hybrid")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:description_html]).to include("CDI")
    expect(result[:posted_at]).to be_a(Time)
  end

  it "returns nil for unknown fields" do
    result = step.call(html_content: "<html><body><h1></h1></body></html>")

    expect(result[:company]).to be_nil
    expect(result[:employment_type]).to be_nil
  end
end
