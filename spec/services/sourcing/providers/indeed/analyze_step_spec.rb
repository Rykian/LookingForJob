require "rails_helper"

RSpec.describe Sourcing::Providers::Indeed::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  it "extracts fields from JSON-LD JobPosting as primary source" do
    html = <<~HTML
      <html>
        <body>
          <h1 data-testid="jobsearch-JobInfoHeader-title">Senior Ruby Developer</h1>
          <div data-testid="inlineHeader-companyName">ExampleCorp</div>
          <div data-testid="inlineHeader-companyLocation">Paris (75001)</div>
          <div id="jobDescriptionText" class="some-class" style="color:red">
            <p>Concevoir et maintenir des applications Ruby on Rails.</p>
            <p>5+ ans d'experience requise.</p>
            <script>tracking()</script>
          </div>
          <script type="application/ld+json">
          {
            "@context": "http://schema.org",
            "@type": "JobPosting",
            "title": "Senior Ruby Developer",
            "datePosted": "2026-03-18",
            "employmentType": "FULL_TIME",
            "hiringOrganization": {"@type":"Organization","name":"ExampleCorp"},
            "jobLocation": {"@type":"Place","address":{"@type":"PostalAddress","addressLocality":"Paris"}},
            "jobLocationType": "TELECOMMUTE",
            "baseSalary": {
              "@type": "MonetaryAmount",
              "currency": "EUR",
              "value": {"@type":"QuantitativeValue","minValue":50000,"maxValue":70000,"unitText":"YEAR"}
            }
          }
          </script>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Senior Ruby Developer")
    expect(result[:company]).to eq("ExampleCorp")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("FULL_TIME")
    expect(result[:salary_min_minor]).to eq(50_000)
    expect(result[:salary_max_minor]).to eq(70_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to eq("2026-03-18")
    expect(result[:description_html]).to include("Ruby on Rails")
    expect(result[:description_html]).not_to include("tracking()")
    expect(result[:description_html]).not_to include("class=")
    expect(result[:description_html]).not_to include("style=")
  end

  it "falls back to DOM selectors when JSON-LD is absent" do
    html = <<~HTML
      <html><body>
        <h1 data-testid="jobsearch-JobInfoHeader-title">Developpeur Full-Stack</h1>
        <div data-testid="inlineHeader-companyName">Acme</div>
        <div data-testid="inlineHeader-companyLocation">Lyon</div>
        <div id="jobDescriptionText"><p>CDI temps plein - hybride 3 jours sur site.</p></div>
      </body></html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Developpeur Full-Stack")
    expect(result[:company]).to eq("Acme")
    expect(result[:city]).to eq("Lyon")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:salary_min_minor]).to be_nil
    expect(result[:posted_at]).to be_nil
  end

  it "normalizes monthly salaries to yearly amounts" do
    html = <<~HTML
      <html><body>
        <script type="application/ld+json">
        {"@type":"JobPosting","title":"X","baseSalary":{"@type":"MonetaryAmount","currency":"EUR","value":{"minValue":4000,"maxValue":5000,"unitText":"MONTH"}}}
        </script>
      </body></html>
    HTML

    result = step.call(html_content: html)
    expect(result[:salary_min_minor]).to eq(48_000)
    expect(result[:salary_max_minor]).to eq(60_000)
    expect(result[:salary_currency]).to eq("EUR")
  end

  it "maps JSON-LD CONTRACTOR to FREELANCE" do
    html = <<~HTML
      <html><body>
        <script type="application/ld+json">
        {"@type":"JobPosting","title":"X","employmentType":"CONTRACTOR"}
        </script>
      </body></html>
    HTML

    expect(step.call(html_content: html)[:employment_type]).to eq("FREELANCE")
  end

  it "returns nil for missing fields without crashing" do
    result = step.call(html_content: "<html><body><h1>Just a title</h1></body></html>")

    expect(result[:title]).to eq("Just a title")
    expect(result[:company]).to be_nil
    expect(result[:salary_min_minor]).to be_nil
    expect(result[:location_mode]).to be_nil
    expect(result[:description_html]).to be_nil
  end
end
