require "rails_helper"

RSpec.describe Sourcing::Providers::FranceTravail::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  # Builds HTML that mirrors the real France-Travail detail page structure
  # (verified against live HTML on 2026-04-03).
  def build_html(overrides = {})
    defaults = {
      title:       "Développeur Ruby (H/F)",
      company:     "ACME Corp",
      city:        "63 - Clermont-Ferrand",
      contract_dd: "CDI\nContrat travail",
      conditions:  "Possibilité de télétravail",
      salary_min:  "50000.0",
      salary_max:  "60000.0",
      salary_unit: "YEAR",
      posted_at:   "2026-04-03",
      description: "<p>Nous recherchons un <strong>développeur Ruby</strong>.</p>",
    }
    f = defaults.merge(overrides)

    <<~HTML
      <!DOCTYPE html><html lang="fr"><body>
        <div itemtype="http://schema.org/JobPosting" itemscope="" class="modal-body">
          <h1 class="t2 title">
            <span itemprop="title">#{f[:title]}</span>
          </h1>
          <p itemprop="jobLocation" itemscope="">
            <span itemprop="address" itemscope="">
              <span itemprop="name">#{f[:city]}</span>
            </span>
          </p>
          <p class="t5 title-complementary">
            <span content="#{f[:posted_at]}" itemprop="datePosted">Actualisé le 03 avril 2026</span>
          </p>
          <div class="row">
            <div itemprop="description" class="description col-sm-8">
              #{f[:description]}
            </div>
            <div class="description-aside col-sm-4">
              <dl class="icon-group">
                <dt><span title="Type de contrat" aria-hidden="true" class="icon-wa-redaction"></span><span class="sr-only">Type de contrat</span></dt>
                <dd>#{f[:contract_dd]}</dd>
                <dt><span title="Durée du travail" aria-hidden="true" class="icon-clock"></span><span class="sr-only">Durée du travail</span></dt>
                <dd itemprop="workHours">39H/semaine</dd>
                <dt><span title="Conditions de travail" aria-hidden="true" class="icon-info-point"></span><span class="sr-only">Conditions de travail</span></dt>
                <dd>#{f[:conditions]}</dd>
                <dt><span title="Salaire" aria-hidden="true" class="icon-salaire"></span><span class="sr-only">Salaire</span></dt>
                <dd>
                  <span itemprop="baseSalary" itemscope="" itemtype="http://schema.org/MonetaryAmount">
                    <span content="EUR" itemprop="currency"></span>
                    <span itemprop="value" itemscope="" itemtype="http://schema.org/QuantitativeValue">
                      <span content="#{f[:salary_min]}" itemprop="minValue"></span>
                      <span content="#{f[:salary_max]}" itemprop="maxValue"></span>
                      <span content="#{f[:salary_unit]}" itemprop="unitText"></span>
                    </span>
                  </span>
                </dd>
              </dl>
            </div>
          </div>
          <span itemscope="" itemprop="hiringOrganization" itemtype="http://schema.org/Organization">
            <span content="#{f[:company]}" itemprop="name"></span>
          </span>
        </div>
      </body></html>
    HTML
  end

  it "extracts all core fields from a standard CDI offer" do
    result = step.call(html_content: build_html)

    expect(result[:title]).to eq("Développeur Ruby (H/F)")
    expect(result[:company]).to eq("ACME Corp")
    expect(result[:city]).to eq("Clermont-ferrand")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:salary_min_minor]).to eq(50_000)
    expect(result[:salary_max_minor]).to eq(60_000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:posted_at]).to match(/\A2026-04-03T/)
    expect(result[:description_html]).to include("développeur Ruby")
  end

  describe "city normalization" do
    it "strips department prefix" do
      result = step.call(html_content: build_html(city: "75 - PARIS 01"))
      expect(result[:city]).to eq("Paris 01")
    end

    it "returns nil when city is absent" do
      result = step.call(html_content: build_html(city: ""))
      expect(result[:city]).to be_nil
    end
  end

  describe "contract type mapping" do
    {
      "CDI\nContrat travail"       => "PERMANENT",
      "CDD\nContrat à durée dét."  => "FIXED_TERM",
      "Intérim"                    => "TEMPORARY",
      "Contrat d'apprentissage"    => "APPRENTICESHIP",
      "Profession libérale"        => "FREELANCE",
      "Contrat saisonnier"         => "FIXED_TERM",
    }.each do |text, expected|
      it "maps '#{text.lines.first.strip}' to #{expected}" do
        result = step.call(html_content: build_html(contract_dd: text))
        expect(result[:employment_type]).to eq(expected)
      end
    end

    it "returns nil for unknown contract text" do
      result = step.call(html_content: build_html(contract_dd: "Contrat inconnu"))
      expect(result[:employment_type]).to be_nil
    end
  end

  describe "salary parsing (schema.org microdata)" do
    it "uses annual values as-is" do
      result = step.call(html_content: build_html(salary_min: "40000.0", salary_max: "55000.0", salary_unit: "YEAR"))
      expect(result[:salary_min_minor]).to eq(40_000)
      expect(result[:salary_max_minor]).to eq(55_000)
      expect(result[:salary_currency]).to eq("EUR")
    end

    it "annualizes monthly values" do
      result = step.call(html_content: build_html(salary_min: "2000.0", salary_max: "2500.0", salary_unit: "MONTH"))
      expect(result[:salary_min_minor]).to eq(24_000)
      expect(result[:salary_max_minor]).to eq(30_000)
    end

    it "returns nil for hourly salary (HOUR unit)" do
      result = step.call(html_content: build_html(salary_min: "15.0", salary_max: "20.0", salary_unit: "HOUR"))
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
    end

    it "returns nil when salary nodes are absent" do
      html = build_html.gsub(/<span itemprop="baseSalary".*?<\/span>\s*<\/dd>/m, "<dd></dd>")
      result = step.call(html_content: html)
      # Gracefully returns nil
      expect(result[:salary_min_minor]).to be_nil
    end
  end

  describe "location_mode detection from Conditions de travail" do
    it "detects remote from télétravail total" do
      result = step.call(html_content: build_html(conditions: "Télétravail total"))
      expect(result[:location_mode]).to eq("remote")
    end

    it "detects hybrid from possibilité de télétravail" do
      result = step.call(html_content: build_html(conditions: "Possibilité de télétravail"))
      expect(result[:location_mode]).to eq("hybrid")
    end

    it "defaults to on-site when no télétravail mention" do
      result = step.call(html_content: build_html(conditions: "Travail en journée"))
      expect(result[:location_mode]).to eq("on-site")
    end

    it "falls back to description text when Conditions de travail is missing" do
      html = build_html(
        conditions: "",
        description: "<p>Poste avec possibilité de télétravail 2 jours par semaine.</p>"
      ).gsub(/<dt><span title="Conditions de travail".*?<\/dd>/m, "")

      result = step.call(html_content: html)
      expect(result[:location_mode]).to eq("hybrid")
    end
  end

  describe "description_html" do
    it "returns inner HTML of the description node" do
      result = step.call(html_content: build_html(description: "<p>Job <em>description</em> here</p>"))
      expect(result[:description_html]).to include("<em>description</em>")
    end

    it "returns nil when description is absent" do
      html = build_html.gsub(/itemprop="description"/, 'itemprop="OTHER"')
      result = step.call(html_content: html)
      expect(result[:description_html]).to be_nil
    end
  end
end
