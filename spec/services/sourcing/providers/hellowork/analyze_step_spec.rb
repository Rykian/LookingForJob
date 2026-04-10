require "rails_helper"

RSpec.describe Sourcing::Providers::Hellowork::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  it "extracts fields from JSON-LD JobPosting first" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "JobPosting",
              "title": "Developpeur Ruby on Rails H/F",
              "description": "<p>Mission backend Ruby on Rails.</p>",
              "hiringOrganization": { "name": "Savane Consulting" },
              "jobLocation": { "address": { "addressLocality": "Rennes" } },
              "employmentType": "FULL_TIME",
              "datePosted": "2026-03-31T17:29:14Z",
              "baseSalary": {
                "@type": "MonetaryAmount",
                "currency": "EUR",
                "value": {
                  "@type": "QuantitativeValue",
                  "minValue": 45000,
                  "maxValue": 60000,
                  "unitText": "YEAR"
                }
              },
              "jobLocationType": "TELECOMMUTE"
            }
          </script>
        </head>
        <body>
          <h1>Developpeur Ruby on Rails H/F</h1>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Developpeur Ruby on Rails H/F")
    expect(result[:company]).to eq("Savane Consulting")
    expect(result[:city]).to eq("Rennes")
    expect(result[:employment_type]).to eq("FULL_TIME")
    expect(result[:salary_min_minor]).to eq(45_000)
    expect(result[:salary_max_minor]).to eq(60_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to eq("2026-03-31T17:29:14Z")
    expect(result[:description_html]).to include("Mission backend Ruby on Rails")
  end

  it "falls back to DOM metadata when JSON-LD fields are missing" do
    html = <<~HTML
      <html>
        <body>
          <h1>
            Developpeur Ruby H/F
            <a href="/fr-fr/entreprises/celad-123.html">CELAD</a>
          </h1>
          <ul>
            <li>Strasbourg - 67</li>
            <li>CDI</li>
            <li>35 000 - 40 000 € / an</li>
            <li>Teletravail partiel</li>
          </ul>
          <section>
            <h2><span>Détail du poste</span></h2>
            <div>
              <div data-controller="truncate-text">
                <div data-truncate-text-target="content" class="line-clamp">
                  <p>Developper des APIs Ruby on Rails.</p>
                  <p>Contribuer a la modernisation du legacy.</p>
                </div>
                <button type="button">Voir plus</button>
              </div>
            </div>
          </section>
          <details class="profile-collapsed">
            <summary>
              <h2><span>Le profil recherche</span></h2>
            </summary>
            <div>
              <p>5 ans d'experience.</p>
            </div>
          </details>
          <details>
            <summary>
              <h2><span>Les avantages</span></h2>
            </summary>
            <ul>
              <li>Mutuelle</li>
            </ul>
          </details>
          <p aria-label="Publiee le 31/03/2026">Publiee le 31/03/2026</p>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Developpeur Ruby H/F CELAD")
    expect(result[:company]).to eq("CELAD")
    expect(result[:city]).to eq("Strasbourg")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:salary_min_minor]).to eq(35_000)
    expect(result[:salary_max_minor]).to eq(40_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:posted_at]).to eq("2026-03-31")
    expect(result[:description_html]).to include("Détail du poste")
    expect(result[:description_html]).to include("Contribuer a la modernisation du legacy")
    expect(result[:description_html]).to include("Le profil recherche")
    expect(result[:description_html]).to include("5 ans d'experience")
    expect(result[:description_html]).to include("Les avantages")
    expect(result[:description_html]).to include("Mutuelle")
    expect(result[:description_html]).not_to include("Voir plus")
    expect(result[:description_html]).not_to include("class=")
  end

  it "keeps nil for unavailable values" do
    html = "<html><body><h1>Offre sans donnees</h1></body></html>"
    result = step.call(html_content: html)

    expect(result[:salary_min_minor]).to be_nil
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:location_mode]).to be_nil
  end
end
