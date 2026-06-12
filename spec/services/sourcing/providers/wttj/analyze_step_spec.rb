require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  let(:sample_html) do
    <<-HTML
      <html>
        <body>
          <h1>Job Title Example</h1>
          <a href="/companies/example">Company Name</a>
          <div class="location">Paris, Montpellier</div>
          <div class="contract">CDI</div>
          <div class="salary">50K à 80K €</div>
          <div>Télétravail total</div>
          <div class="posted">il y a 8 jours</div>
          <section>
            <h3>Descriptif du poste</h3>
            <div>Job description here</div>
          </section>
        </body>
      </html>
    HTML
  end

  it "flags offers that show the WTTJ disabled banner" do
    html = <<~HTML
      <html><body>
        <h1>Développeur Full Stack</h1>
        <div><span>Cette offre n’est plus disponible.</span></div>
      </body></html>
    HTML

    expect(step.call(html: html)[:disabled]).to eq(true)
  end

  it "marks active offers as not disabled" do
    expect(step.call(html: sample_html)[:disabled]).to eq(false)
  end

  it "extracts and normalizes fields from DOM fallback HTML" do
    result = step.call(html: sample_html)
    expect(result[:title]).to eq("Job Title Example")
    expect(result[:company_name]).to eq("Company Name")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:salary_min_minor]).to eq(50000)
    expect(result[:salary_max_minor]).to eq(80000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to match(/T\d{2}:\d{2}:\d{2}/)
    expect(result[:description_html]).to include("Job description here")
  end

  it "handles missing and non-standard fields gracefully" do
    html = <<-HTML
      <html><body>
        <h1>Another Job</h1>
        <a href="/companies/other">OtherCo</a>
        <div class="location"></div>
        <div class="contract">Freelance</div>
        <div class="salary">Non spécifié</div>
        <div>Hybride</div>
        <div class="posted">il y a 2 heures</div>
        <section><h3>Descriptif du poste</h3><div>Other description</div></section>
      </body></html>
    HTML
    result = step.call(html: html)
    expect(result[:city]).to be_nil
    expect(result[:employment_type]).to eq("FREELANCE")
    expect(result[:salary_min_minor]).to be_nil
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:salary_currency]).to be_nil
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:posted_at]).to match(/T\d{2}:\d{2}:\d{2}/)
  end

  it "parses salary with only min value" do
    html = <<-HTML
      <html><body>
        <h1>Solo Salary</h1>
        <a href="/companies/solo">SoloCo</a>
        <div class="location">Lyon</div>
        <div class="contract">CDD</div>
        <div class="salary">60K €</div>
        <div>Sur site</div>
        <div class="posted">31/03/2026</div>
        <section><h3>Descriptif du poste</h3><div>Solo description</div></section>
      </body></html>
    HTML
    result = step.call(html: html)
    expect(result[:salary_min_minor]).to eq(60000)
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:employment_type]).to eq("FIXED_TERM")
    expect(result[:location_mode]).to eq("on-site")
    expect(result[:posted_at]).to match(/2026-03-31T/)
  end

  it "extracts fields from JSON-LD JobPosting (Next.js SEO payload)" do
    jsonld = {
      "@context" => "https://schema.org",
      "@type" => "JobPosting",
      "title" => "Senior Software Engineer RoR",
      "datePosted" => "2026-03-03T11:19:08Z",
      "employmentType" => "FULL_TIME",
      "description" => "<p>Backend job description</p>",
      "hiringOrganization" => { "@type" => "Organization", "name" => "Bluecoders" },
      "jobLocation" => { "@type" => "Place", "address" => { "addressLocality" => "Paris" } },
      "jobLocationType" => "TELECOMMUTE",
      "baseSalary" => {
        "@type" => "MonetaryAmount",
        "currency" => "EUR",
        "value" => { "@type" => "QuantitativeValue", "minValue" => 50_000, "maxValue" => 80_000 },
      },
    }.to_json

    html = <<~HTML
      <html><head>
        <script type="application/ld+json">#{jsonld}</script>
      </head><body><h1>Senior Software Engineer RoR</h1></body></html>
    HTML

    result = step.call(html: html)
    expect(result[:title]).to eq("Senior Software Engineer RoR")
    expect(result[:company_name]).to eq("Bluecoders")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("FULL_TIME")
    expect(result[:salary_min_minor]).to eq(50_000)
    expect(result[:salary_max_minor]).to eq(80_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to eq("2026-03-03T11:19:08Z")
    expect(result[:description_html]).to include("Backend job description")
  end

  it "extracts fields from legacy window.__INITIAL_DATA__ fallback" do
    payload = {
      "queries" => [
        {
          "queryKey" => ["job", "fr", "bluecoders", "senior-software-engineer-ror_paris"],
          "state" => {
            "data" => {
              "name" => "Senior Software Engineer RoR",
              "contract_type" => "full_time",
              "salary_min" => 1,
              "salary_max" => 1000,
              "salary_currency" => "EUR",
              "remote" => "partial",
              "published_at" => "2026-03-03T11:19:08Z",
              "description" => "<p>Backend job description</p>",
              "office" => { "city" => "Paris" },
              "organization" => { "name" => "Bluecoders" },
            },
          },
        },
      ],
    }.to_json.to_json

    html = <<~HTML
      <html><body>
        <script>
          window.__INITIAL_DATA__ = #{payload}
          window.__GROWTHBOOK_PAYLOAD__ = "{}"
        </script>
        <div>le mois dernier</div>
      </body></html>
    HTML

    result = step.call(html: html)
    expect(result[:title]).to eq("Senior Software Engineer RoR")
    expect(result[:company_name]).to eq("Bluecoders")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("FULL_TIME")
    expect(result[:salary_min_minor]).to eq(1)
    expect(result[:salary_max_minor]).to eq(1000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:posted_at]).to eq("last month")
    expect(result[:description_html]).to include("Backend job description")
  end
end
