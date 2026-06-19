require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  # Mirrors a real WeLoveDevs Algolia `public_jobs` object (the body FetchStep stores).
  def hit(overrides = {})
    {
      "objectID" => "greenhouse+5967999002",
      "type" => "company_job",
      "title" => "Backend Engineer w/m ",
      "smallCompany" => { "companyName" => "DataDome" },
      "formattedPlaces" => ["Paris, France"],
      "contractTypes" => ["permanent"],
      "details" => {
        "salary" => { "currency" => "€", "min" => 45, "max" => 55, "recurrence" => "year" },
        "remotePolicy" => { "frequency" => "fullTime" },
      },
      "publishDate" => 1_749_112_647_000,
      "createdAt" => 1_748_858_400_000,
      "mdDescription" => "**About the team**\n\nBuild robust APIs in Go.",
    }.merge(overrides).to_json
  end

  describe "#call" do
    let(:result) { step.call(html_content: hit) }

    it "extracts and trims the title" do
      expect(result[:title]).to eq("Backend Engineer w/m")
    end

    it "extracts the company from smallCompany.companyName" do
      expect(result[:company_name]).to eq("DataDome")
    end

    it "extracts the city from the first formattedPlaces entry" do
      expect(result[:city]).to eq("Paris, France")
    end

    it "maps contractTypes to the employment_type enum" do
      expect(result[:employment_type]).to eq("PERMANENT")
    end

    it "scales the salary to whole units and normalizes the currency to EUR" do
      expect(result[:salary_min_minor]).to eq(45_000)
      expect(result[:salary_max_minor]).to eq(55_000)
      expect(result[:salary_currency]).to eq("EUR")
    end

    it "maps remotePolicy.frequency fullTime to remote" do
      expect(result[:location_mode]).to eq("remote")
    end

    it "converts the epoch-ms publishDate to an ISO8601 timestamp" do
      expect(result[:posted_at]).to eq("2025-06-05T08:37:27Z")
    end

    it "renders the markdown description to HTML stripped of style/class attributes" do
      expect(result[:description_html]).to include("About the team", "Build robust APIs in Go")
      expect(result[:description_html]).to include("<strong>")
      expect(result[:description_html]).not_to include("style=")
      expect(result[:description_html]).not_to include("class=")
    end
  end

  describe "contract priority" do
    it "prefers permanent over a co-listed internship" do
      expect(step.call(html_content: hit("contractTypes" => %w[internship permanent]))[:employment_type]).to eq("PERMANENT")
    end

    it "maps a freelance-only offer to FREELANCE" do
      expect(step.call(html_content: hit("contractTypes" => ["freelance"]))[:employment_type]).to eq("FREELANCE")
    end
  end

  describe "salary tolerance" do
    it "reads only the yearly channel (monthly recurrence yields no salary)" do
      monthly = hit("details" => { "salary" => { "min" => 4, "max" => 5, "recurrence" => "month" } })
      result = step.call(html_content: monthly)
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
    end

    it "defaults currency to EUR when amounts are present but the symbol is missing" do
      no_currency = hit("details" => { "salary" => { "min" => 45, "max" => 55, "recurrence" => "year" } })
      expect(step.call(html_content: no_currency)[:salary_currency]).to eq("EUR")
    end
  end

  describe "location_mode from remotePolicy.frequency" do
    def mode(frequency)
      step.call(html_content: hit("details" => { "remotePolicy" => { "frequency" => frequency } }))[:location_mode]
    end

    it { expect(mode("fullTime")).to eq("remote") }
    it { expect(mode("hybrid")).to eq("hybrid") }
    it { expect(mode("no")).to eq("on-site") }
    it "returns nil when the policy omits frequency" do
      expect(step.call(html_content: hit("details" => { "remotePolicy" => {} }))[:location_mode]).to be_nil
    end
  end

  describe "missing-field tolerance" do
    it "returns nil for fields when the payload is malformed, without raising" do
      result = step.call(html_content: "<html>not json</html>")
      expect(result[:title]).to be_nil
      expect(result[:company_name]).to be_nil
      expect(result[:city]).to be_nil
      expect(result[:employment_type]).to be_nil
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:location_mode]).to be_nil
      expect(result[:posted_at]).to be_nil
      expect(result[:description_html]).to be_nil
    end
  end
end
