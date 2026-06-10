require "rails_helper"

RSpec.describe Sourcing::Providers::CollectiveWork::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  # Builds the embedded __NEXT_DATA__ blob that the SSR page carries.
  def build_html(project:)
    payload = { "props" => { "pageProps" => { "project" => project } } }
    %(<html><body><script id="__NEXT_DATA__" type="application/json">#{payload.to_json}</script></body></html>)
  end

  let(:permanent_project) do
    {
      "id" => "abc",
      "name" => "Senior Backend Engineer",
      "description" => %(<p style="color:red" class="x"><strong>Mission</strong></p><p>Build APIs.</p><script>console.log('noise')</script>),
      "profileWanted" => "<ul><li>5+ years</li></ul>",
      "budgetBrief" => "70 000 € - 85 000 €",
      "workPreferences" => ["HYBRID"],
      "isPermanentContract" => true,
      "location" => { "fullNameFrench" => "Paris, France", "fullNameEnglish" => "Paris, France" },
      "company" => { "name" => "Fynd Recrutement" },
      "publishedAt" => "2026-06-09T18:03:50.557Z",
      "createdAt" => "2026-06-09T18:03:50.557Z",
    }
  end

  describe "#call with a permanent (CDI) project" do
    let(:result) { step.call(html_content: build_html(project: permanent_project)) }

    it "extracts the title" do
      expect(result[:title]).to eq("Senior Backend Engineer")
    end

    it "extracts the company" do
      expect(result[:company]).to eq("Fynd Recrutement")
    end

    it "extracts the city (first component of fullNameFrench)" do
      expect(result[:city]).to eq("Paris")
    end

    it "maps isPermanentContract=true to PERMANENT" do
      expect(result[:employment_type]).to eq("PERMANENT")
    end

    it "parses an annual range from budgetBrief" do
      expect(result[:salary_min_minor]).to eq(70_000)
      expect(result[:salary_max_minor]).to eq(85_000)
      expect(result[:salary_currency]).to eq("EUR")
    end

    it "maps workPreferences=[HYBRID] to hybrid" do
      expect(result[:location_mode]).to eq("hybrid")
    end

    it "uses publishedAt for posted_at" do
      expect(result[:posted_at]).to eq("2026-06-09T18:03:50.557Z")
    end

    it "returns description HTML stripped of scripts and presentational attributes" do
      expect(result[:description_html]).to include("Mission", "Build APIs", "5+ years")
      expect(result[:description_html]).not_to include("console.log")
      expect(result[:description_html]).not_to include("style=")
      expect(result[:description_html]).not_to include("class=")
    end
  end

  describe "#call with a freelance project" do
    let(:freelance_project) do
      permanent_project.merge(
        "isPermanentContract" => false,
        "budgetBrief" => "550€/jour",
        "workPreferences" => ["REMOTE"]
      )
    end

    let(:result) { step.call(html_content: build_html(project: freelance_project)) }

    it "maps isPermanentContract=false to FREELANCE" do
      expect(result[:employment_type]).to eq("FREELANCE")
    end

    it "leaves salary fields nil for freelance daily-rate budgets" do
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
      expect(result[:salary_currency]).to be_nil
    end

    it "maps workPreferences=[REMOTE] to remote" do
      expect(result[:location_mode]).to eq("remote")
    end
  end

  describe "workPreferences priority" do
    it "picks remote over hybrid when both are accepted" do
      project = permanent_project.merge("workPreferences" => ["HYBRID", "REMOTE"])
      result = step.call(html_content: build_html(project: project))
      expect(result[:location_mode]).to eq("remote")
    end

    it "picks hybrid over on-site when both are accepted" do
      project = permanent_project.merge("workPreferences" => ["ON_SITE", "HYBRID"])
      result = step.call(html_content: build_html(project: project))
      expect(result[:location_mode]).to eq("hybrid")
    end

    it "maps ON_SITE to on-site" do
      project = permanent_project.merge("workPreferences" => ["ON_SITE"])
      result = step.call(html_content: build_html(project: project))
      expect(result[:location_mode]).to eq("on-site")
    end

    it "returns nil when workPreferences is empty" do
      project = permanent_project.merge("workPreferences" => [])
      result = step.call(html_content: build_html(project: project))
      expect(result[:location_mode]).to be_nil
    end
  end

  describe "salary edge cases (permanent contract only)" do
    it "parses a single annual amount" do
      project = permanent_project.merge("budgetBrief" => "65000 €")
      result = step.call(html_content: build_html(project: project))
      expect(result[:salary_min_minor]).to eq(65_000)
      expect(result[:salary_max_minor]).to be_nil
    end

    it "parses a k-suffix single amount (45k€+)" do
      project = permanent_project.merge("budgetBrief" => "45k€+ (Annuel)")
      result = step.call(html_content: build_html(project: project))
      expect(result[:salary_min_minor]).to eq(45_000)
    end

    it "parses a k-suffix range where k applies to both bounds (55-75k)" do
      project = permanent_project.merge("budgetBrief" => "55-75k")
      result = step.call(html_content: build_html(project: project))
      expect(result[:salary_min_minor]).to eq(55_000)
      expect(result[:salary_max_minor]).to eq(75_000)
    end

    it "ignores implausibly low annual values (likely a daily-rate label leak)" do
      project = permanent_project.merge("budgetBrief" => "500 €")
      result = step.call(html_content: build_html(project: project))
      expect(result[:salary_min_minor]).to be_nil
    end

    it "ignores nil budgetBrief" do
      project = permanent_project.merge("budgetBrief" => nil)
      result = step.call(html_content: build_html(project: project))
      expect(result[:salary_min_minor]).to be_nil
    end
  end

  describe "missing-field tolerance" do
    it "returns nils when __NEXT_DATA__ is absent, without raising" do
      result = step.call(html_content: "<html><body><h1>X</h1></body></html>")
      expect(result[:title]).to be_nil
      expect(result[:company]).to be_nil
      expect(result[:city]).to be_nil
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:location_mode]).to be_nil
      expect(result[:description_html]).to be_nil
    end

    it "returns nils when project is null" do
      result = step.call(html_content: build_html(project: nil))
      expect(result[:title]).to be_nil
    end
  end
end
