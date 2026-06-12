require "rails_helper"

RSpec.describe Sourcing::Providers::FreeWork::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  let(:permanent_posting) do
    {
      "id" => 621_936,
      "title" => "Développeur Ruby On Rails (H/F)",
      "slug" => "developpeur-ruby-on-rails-h-f-8",
      "description" => %(<p style="color:red" class="x"><strong>Mission</strong></p><p>Build APIs.</p><script>console.log('noise')</script>),
      "candidateProfile" => "<ul><li>5+ years</li></ul>",
      "companyDescription" => "<p>Recruiter boilerplate.</p>",
      "company" => { "name" => "CELAD" },
      "location" => { "locality" => "Strasbourg", "adminLevel1" => "Grand Est", "countryCode" => "FR" },
      "contracts" => ["permanent"],
      "minAnnualSalary" => 35_000,
      "maxAnnualSalary" => 42_000,
      "minDailySalary" => nil,
      "maxDailySalary" => nil,
      "currency" => "EUR",
      "remoteMode" => "partial",
      "experienceLevel" => "intermediate",
      "publishedAt" => "2026-06-08T14:28:15+02:00",
      "createdAt" => "2026-06-01T10:00:00+02:00",
    }
  end

  describe "#call with a permanent (CDI) posting" do
    let(:result) { step.call(html_content: permanent_posting.to_json) }

    it "extracts the title" do
      expect(result[:title]).to eq("Développeur Ruby On Rails (H/F)")
    end

    it "extracts the company" do
      expect(result[:company_name]).to eq("CELAD")
    end

    it "extracts the city from location.locality" do
      expect(result[:city]).to eq("Strasbourg")
    end

    it "maps contracts=[permanent] to PERMANENT" do
      expect(result[:employment_type]).to eq("PERMANENT")
    end

    it "reads the annual salary range" do
      expect(result[:salary_min_minor]).to eq(35_000)
      expect(result[:salary_max_minor]).to eq(42_000)
      expect(result[:salary_currency]).to eq("EUR")
    end

    it "maps remoteMode=partial to hybrid" do
      expect(result[:location_mode]).to eq("hybrid")
    end

    it "uses publishedAt for posted_at" do
      expect(result[:posted_at]).to eq("2026-06-08T14:28:15+02:00")
    end

    it "returns description HTML stripped of scripts and presentational attributes" do
      expect(result[:description_html]).to include("Mission", "Build APIs", "5+ years")
      expect(result[:description_html]).not_to include("console.log")
      expect(result[:description_html]).not_to include("style=")
      expect(result[:description_html]).not_to include("class=")
    end

    it "drops the companyDescription boilerplate" do
      expect(result[:description_html]).not_to include("Recruiter boilerplate")
    end
  end

  describe "#call with a freelance posting" do
    let(:freelance_posting) do
      permanent_posting.merge(
        "contracts" => ["contractor"],
        "minAnnualSalary" => nil,
        "maxAnnualSalary" => nil,
        "minDailySalary" => 400,
        "maxDailySalary" => 550,
        "remoteMode" => "full"
      )
    end

    let(:result) { step.call(html_content: freelance_posting.to_json) }

    it "maps contracts=[contractor] to FREELANCE" do
      expect(result[:employment_type]).to eq("FREELANCE")
    end

    it "leaves salary fields nil (daily rates are a different scale)" do
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
      expect(result[:salary_currency]).to be_nil
    end

    it "maps remoteMode=full to remote" do
      expect(result[:location_mode]).to eq("remote")
    end
  end

  describe "contract mapping" do
    it "prefers PERMANENT when an offer accepts several contract types" do
      posting = permanent_posting.merge("contracts" => ["contractor", "permanent"])
      result = step.call(html_content: posting.to_json)
      expect(result[:employment_type]).to eq("PERMANENT")
    end

    it "maps fixed-term to FIXED_TERM" do
      posting = permanent_posting.merge("contracts" => ["fixed-term"])
      result = step.call(html_content: posting.to_json)
      expect(result[:employment_type]).to eq("FIXED_TERM")
    end

    it "maps apprenticeship to APPRENTICESHIP" do
      posting = permanent_posting.merge("contracts" => ["apprenticeship"])
      result = step.call(html_content: posting.to_json)
      expect(result[:employment_type]).to eq("APPRENTICESHIP")
    end

    it "returns nil for unknown or empty contracts" do
      expect(step.call(html_content: permanent_posting.merge("contracts" => ["mystery"]).to_json)[:employment_type]).to be_nil
      expect(step.call(html_content: permanent_posting.merge("contracts" => []).to_json)[:employment_type]).to be_nil
    end
  end

  describe "location mode mapping" do
    it "maps remoteMode=none to on-site" do
      posting = permanent_posting.merge("remoteMode" => "none")
      expect(step.call(html_content: posting.to_json)[:location_mode]).to eq("on-site")
    end

    it "returns nil when remoteMode is null or unknown" do
      expect(step.call(html_content: permanent_posting.merge("remoteMode" => nil).to_json)[:location_mode]).to be_nil
      expect(step.call(html_content: permanent_posting.merge("remoteMode" => "weird").to_json)[:location_mode]).to be_nil
    end
  end

  describe "salary edge cases" do
    it "uses max as min when only maxAnnualSalary is present" do
      posting = permanent_posting.merge("minAnnualSalary" => nil, "maxAnnualSalary" => 42_000)
      result = step.call(html_content: posting.to_json)
      expect(result[:salary_min_minor]).to eq(42_000)
      expect(result[:salary_max_minor]).to eq(42_000)
    end

    it "defaults currency to EUR when blank" do
      posting = permanent_posting.merge("currency" => nil)
      expect(step.call(html_content: posting.to_json)[:salary_currency]).to eq("EUR")
    end

    it "ignores zero and negative amounts" do
      posting = permanent_posting.merge("minAnnualSalary" => 0, "maxAnnualSalary" => -1)
      result = step.call(html_content: posting.to_json)
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
      expect(result[:salary_currency]).to be_nil
    end
  end

  describe "missing-field tolerance" do
    it "returns nils when the payload is not valid JSON, without raising" do
      result = step.call(html_content: "<html>not json</html>")
      expect(result[:title]).to be_nil
      expect(result[:company_name]).to be_nil
      expect(result[:city]).to be_nil
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:location_mode]).to be_nil
      expect(result[:description_html]).to be_nil
    end

    it "falls back to createdAt when publishedAt is missing" do
      posting = permanent_posting.merge("publishedAt" => nil)
      expect(step.call(html_content: posting.to_json)[:posted_at]).to eq("2026-06-01T10:00:00+02:00")
    end
  end
end
