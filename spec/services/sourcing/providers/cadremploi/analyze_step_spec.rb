require "rails_helper"

RSpec.describe Sourcing::Providers::Cadremploi::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  # Mimics a Cadremploi detail page with all key fields present.
  let(:full_html) do
    <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "JobPosting",
              "title": "Développeur Ruby on Rails H/F",
              "hiringOrganization": { "name": "Example Corp" },
              "jobLocation": { "address": { "addressLocality": "Paris" } },
              "employmentType": "CDI",
              "datePosted": "2026-04-01",
              "description": "<p>Nous cherchons un développeur expérimenté.</p>"
            }
          </script>
        </head>
        <body>
          <h1>Développeur Ruby on Rails H/F</h1>
          <span class="location">Paris</span>
          <span class="contract-type">CDI</span>
          <span class="salary">45 KEUR - 60 KEUR</span>
          <h2>Quelles sont les missions ?</h2>
          <p>Développer des features en Ruby on Rails, télétravail hybride.</p>
          <h2>Quel est le profil idéal ?</h2>
          <p>5 ans d'expérience minimum, anglais professionnel requis.</p>
          <h2>Informations complémentaires</h2>
          <p>Salaire : 45 KEUR - 60 KEUR</p>
          <h2>Qui a publié cette offre d'emploi ?</h2>
          <h3>Example Corp</h3>
        </body>
      </html>
    HTML
  end

  it "extracts all fields from JSON-LD" do
    result = step.call(html_content: full_html)
    expect(result[:title]).to eq("Développeur Ruby on Rails H/F")
    expect(result[:company]).to eq("Example Corp")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:posted_at]).to eq("2026-04-01")
  end

  it "extracts salary values from JSON-LD MonetaryAmount" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "JobPosting",
              "title": "Backend Engineer H/F",
              "employmentType": "FULL_TIME",
              "baseSalary": {
                "@type": "MonetaryAmount",
                "currency": "EUR",
                "value": {
                  "@type": "QuantitativeValue",
                  "minValue": 40000,
                  "maxValue": 48000,
                  "unitText": "YEAR"
                }
              }
            }
          </script>
        </head>
        <body><h1>Backend Engineer H/F</h1></body>
      </html>
    HTML

    result = step.call(html_content: html)
    expect(result[:employment_type]).to eq("FULL_TIME")
    expect(result[:salary_min_minor]).to eq(40_000)
    expect(result[:salary_max_minor]).to eq(48_000)
    expect(result[:salary_currency]).to eq("EUR")
  end

  let(:dom_html) do
    <<~HTML
      <html>
        <body>
          <h1>Chef de Projet H/F</h1>
          <span class="location">Lyon</span>
          <span class="contract-type">CDD</span>
          <h2>Quelles sont les missions ?</h2>
          <p>Piloter les projets digitaux.</p>
          <h2>Quel est le profil idéal ?</h2>
          <p>Bac+5, télétravail hybride 2 jours.</p>
          <h2>Informations complémentaires</h2>
          <p>35 KEUR - 45 KEUR</p>
          <h2>Qui a publié cette offre d'emploi ?</h2>
          <h3>Acme Consulting</h3>
        </body>
      </html>
    HTML
  end

  it "falls back to DOM selectors when no JSON-LD is present" do
    result = step.call(html_content: dom_html)
    expect(result[:title]).to eq("Chef de Projet H/F")
    expect(result[:city]).to eq("Lyon")
    expect(result[:employment_type]).to eq("FIXED_TERM")
    expect(result[:salary_min_minor]).to eq(35_000)
    expect(result[:salary_max_minor]).to eq(45_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:description_html]).to include("Piloter les projets digitaux")
  end

  it "extracts description from #job-description and #job-profile divs" do
    html = <<~HTML
      <html><body>
        <h1>Data Engineer H/F</h1>
        <section id="job-description">
          <div><p>Construire des pipelines de donnees.</p></div>
        </section>
        <section id="job-profile">
          <div><p>Experience Python et SQL.</p></div>
        </section>
      </body></html>
    HTML

    result = step.call(html_content: html)
    expect(result[:description_html]).to include("Construire des pipelines de donnees")
    expect(result[:description_html]).to include("Experience Python et SQL")
    expect(result[:description_html]).to include("<div>")
  end

  it "returns nil salary for 'Salaire selon profil'" do
    html = <<~HTML
      <html><body>
        <h1>Manager H/F</h1>
        <span class="contract-type">CDI</span>
        <h2>Informations complémentaires</h2>
        <p>Salaire selon profil</p>
      </body></html>
    HTML
    result = step.call(html_content: html)
    expect(result[:salary_min_minor]).to be_nil
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:salary_currency]).to be_nil
  end

  it "parses 'il y a N jours' posted_at from DOM" do
    html = <<~HTML
      <html><body>
        <h1>Consultant H/F</h1>
        <span class="date">Publiée il y a 3 jours</span>
      </body></html>
    HTML
    result = step.call(html_content: html)
    expect(result[:posted_at]).to match(/T\d{2}:\d{2}:\d{2}/)
  end

  it "detects hybrid location mode from description text" do
    html = <<~HTML
      <html><body>
        <h1>Ingénieur H/F</h1>
        <h2>Quelles sont les missions ?</h2>
        <p>Télétravail hybride 3 jours par semaine.</p>
      </body></html>
    HTML
    result = step.call(html_content: html)
    expect(result[:location_mode]).to eq("hybrid")
  end

  it "detects remote location mode from page text" do
    html = <<~HTML
      <html><body>
        <h1>Dev H/F</h1>
        <p>Télétravail total</p>
      </body></html>
    HTML
    result = step.call(html_content: html)
    expect(result[:location_mode]).to eq("remote")
  end

  it "handles all contract type normalizations" do
    {
      "CDI"                  => "PERMANENT",
      "CDD"                  => "FIXED_TERM",
      "Intérim"              => "TEMPORARY",
      "Apprentissage"        => "APPRENTICESHIP",
      "Stage"                => "INTERNSHIP",
      "Contractuel"          => "FIXED_TERM",
      "FULL_TIME"            => "FULL_TIME",
      "PART_TIME"            => "PART_TIME",
    }.each do |raw, expected|
      html = "<html><body><h1>Job</h1><span class=\"contract-type\">#{raw}</span></body></html>"
      result = step.call(html_content: html)
      expect(result[:employment_type]).to eq(expected), "Expected '#{raw}' → '#{expected}', got '#{result[:employment_type]}'"
    end
  end
end
