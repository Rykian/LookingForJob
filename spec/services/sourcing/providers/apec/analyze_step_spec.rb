require "rails_helper"

RSpec.describe Sourcing::Providers::Apec::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  it "extracts fields from rendered Apec offer HTML" do
    html = <<~HTML
      <html>
        <body>
          <article>
            <h1>Développeur Ruby F/H</h1>
            <apec-offre-metadata>
              <div class="card-offer__header d-flex flex-wrap justify-content-start mb-20">
                <div class="card-offer__text">
                  <div class="ref-offre">Ref. Apec : 178367863W</div>
                  <ul class="details-offer-list mb-20">
                    <li>MATSYS CONNECT</li>
                    <li>1 <span>CDI</span></li>
                    <li>Paris 01 - 75</li>
                  </ul>
                  <div class="mb-10 d-flex">
                    <div class="date-offre mb-10">Publiée le 18/03/2026</div>
                    <div class="date-offre">Actualisée le 18/03/2026</div>
                  </div>
                </div>
              </div>
            </apec-offre-metadata>

            <div class="details-post"><h4>Salaire</h4><span>50 - 60 k€ brut annuel</span></div>
            <div class="details-post"><h4>Télétravail</h4><span>Total possible</span></div>
            <div class="details-post">
              <h4>Descriptif du poste</h4>
              <p>Développement et optimisation</p>
              <p>Concevoir, développer et maintenir des applications web.</p>
              <h4>Profil recherché</h4>
              <p>Minimum 5 ans en Ruby on Rails.</p>
              <button type="button" class="btn">Voir plus</button>
            </div>
          </article>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:title]).to eq("Développeur Ruby F/H")
    expect(result[:company]).to eq("MATSYS CONNECT")
    expect(result[:city]).to eq("Paris 01")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:salary_min_minor]).to eq(50_000)
    expect(result[:salary_max_minor]).to eq(60_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to eq("2026-03-18")
    expect(result[:description_html]).to include("Descriptif du poste")
    expect(result[:description_html]).to include("Profil recherché")
    expect(result[:description_html]).to include("Minimum 5 ans en Ruby on Rails")
    expect(result[:description_html]).not_to include("Voir plus")
    expect(result[:description_html]).not_to include("class=")
  end

  it "keeps nil for unavailable values" do
    html = <<~HTML
      <html>
        <body>
          <h1>Offre sans metadonnees</h1>
          <apec-offre-metadata>
            <ul class="details-offer-list">
              <li>Entreprise</li>
              <li><span>CDI</span></li>
              <li>Lyon - 69</li>
            </ul>
          </apec-offre-metadata>
        </body>
      </html>
    HTML

    result = step.call(html_content: html)

    expect(result[:salary_min_minor]).to be_nil
    expect(result[:salary_max_minor]).to be_nil
    expect(result[:location_mode]).to be_nil
    expect(result[:description_html]).to be_nil
  end
end
