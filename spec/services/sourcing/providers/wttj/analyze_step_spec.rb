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
          <h2>Job Title Example</h2>
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

  it "extracts and normalizes fields from sample HTML" do
    result = step.call(html: sample_html)
    expect(result[:title]).to eq("Job Title Example")
    expect(result[:company]).to eq("Company Name")
    expect(result[:city]).to eq("Paris")
    expect(result[:employment_type]).to eq("PERMANENT")
    expect(result[:salary_min_minor]).to eq(50000)
    expect(result[:salary_max_minor]).to eq(80000)
    expect(result[:salary_currency]).to eq("EUR")
    expect(result[:location_mode]).to eq("remote")
    expect(result[:posted_at]).to match(/T\d{2}:\d{2}:\d{2}/) # ISO8601
    expect(result[:description_html]).to include("Job description here")
  end

  it "handles missing and non-standard fields gracefully" do
    html = <<-HTML
      <html><body>
        <h2>Another Job</h2>
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
        <h2>Solo Salary</h2>
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

  # TODO: Add integration tests for analyzing WTTJ job details
end
