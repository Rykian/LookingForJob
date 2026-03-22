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
          <div>Location: Nantes</div>
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
    expect(result[:city]).to eq("Nantes")
  end

  it "extracts title, company, salary and posted_at from job posting json-ld" do
    html = <<~HTML
      <!doctype html>
      <html>
        <body>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "JobPosting",
              "title": "Senior Ruby Engineer",
              "datePosted": "2026-03-19T08:30:00Z",
              "hiringOrganization": {
                "@type": "Organization",
                "name": "Globex"
              },
              "baseSalary": {
                "@type": "MonetaryAmount",
                "currency": "EUR",
                "value": {
                  "@type": "QuantitativeValue",
                  "minValue": 60,
                  "maxValue": 80,
                  "unitText": "YEAR"
                }
              }
            }
          </script>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Senior Ruby Engineer")
    expect(result[:company]).to eq("Globex")
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:salary_min_minor]).to eq(6000)
    expect(result[:salary_max_minor]).to eq(8000)
    expect(result[:posted_at]).to eq(Time.zone.parse("2026-03-19T08:30:00Z"))
  end

  it "extracts salary range and relative posted_at from visible text" do
    html = <<~HTML
      <!doctype html>
      <html>
        <body>
          <span class="posted-time-ago__text">2 days ago</span>
          <div>Compensation range: EUR 60k - EUR 80k</div>
        </body>
      </html>
    HTML

    fixed_now = Time.zone.parse("2026-03-20 12:00:00 UTC")
    allow(Time.zone).to receive(:now).and_return(fixed_now)

    result = step.call(html_content: html)

    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:salary_min_minor]).to eq(6_000_000)
    expect(result[:salary_max_minor]).to eq(8_000_000)
    expect(result[:posted_at]).to eq(Time.zone.parse("2026-03-18 12:00:00 UTC"))
  end

  it "extracts title and company from title tag on logged-in shell pages" do
    html = <<~HTML
      <!doctype html>
      <html>
        <head>
          <title>Software Engineer I | Checkout.com | LinkedIn</title>
        </head>
        <body>
          <script type="text/plain">Reposted 1 week ago</script>
        </body>
      </html>
    HTML

    fixed_now = Time.zone.parse("2026-03-21 12:00:00 UTC")
    allow(Time.zone).to receive(:now).and_return(fixed_now)

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Software Engineer I")
    expect(result[:company]).to eq("Checkout.com")
    expect(result[:salary_min_minor]).to be_nil
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:salary_currency]).to be_nil
    expect(result[:posted_at]).to eq(Time.zone.parse("2026-03-14 12:00:00 UTC"))
  end

  it "extracts posted_at from posted and reposted phrases with plural units" do
    html = <<~HTML
      <!doctype html>
      <html>
        <head>
          <title>Lead Developer | ALKEMI RH | LinkedIn</title>
        </head>
        <body>
          <script type="text/plain">
            Lead Developer · Reposted 2 days ago
            Posted on March 20, 2026, 12:03 PM 9 hours ago
          </script>
        </body>
      </html>
    HTML

    fixed_now = Time.zone.parse("2026-03-21 12:00:00 UTC")
    allow(Time.zone).to receive(:now).and_return(fixed_now)

    result = step.call(html_content: html)

    expect(result[:posted_at]).to eq(Time.zone.parse("2026-03-19 12:00:00 UTC"))
  end

  it "returns nil for unknown fields" do
    result = step.call(html_content: "<html><body><h1></h1></body></html>")

    expect(result[:company]).to be_nil
    expect(result[:employment_type]).to be_nil
  end

  it "extracts top-card location variants from page text" do
    html = <<~HTML
      <!doctype html>
      <html>
        <body>
          <div>Paris, Ile-de-France, France · Reposted 1 day ago · 15 people clicked apply</div>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:city]).to eq("Paris, Ile-de-France, France")
  end

  it "normalizes metropolitan region location labels" do
    html = <<~HTML
      <!doctype html>
      <html>
        <body>
          <div>Greater Paris Metropolitan Region · Reposted 2 weeks ago · 26 people clicked apply</div>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:city]).to eq("Paris et périphérie")
  end
end
