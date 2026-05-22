require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::AnalyzeStep do
  subject(:step) { described_class.new }

  let(:html) do
    <<~HTML
      <section class="top-card-layout">
        <a href="https://example.com" class="topcard__org-name-link">Cozycozy</a>
        <h2 class="top-card-layout__title">Junior Backend Engineer - Typescript</h2>
        <h4>
          <div class="topcard__flavor-row">
            <span class="topcard__flavor">Cozycozy</span>
            <span class="topcard__flavor topcard__flavor--bullet">Paris, Île-de-France, France</span>
          </div>
          <div class="topcard__flavor-row">
            <span class="posted-time-ago__text">3 days ago</span>
            <span class="num-applicants__caption">55 applicants</span>
          </div>
        </h4>
      </section>
      <div class="show-more-less-html__markup" style="color:red" class="x">
        <p style="font-weight:bold">About the role</p>
        <p>Build robust APIs in TypeScript.</p>
        <script>console.log("noise")</script>
      </div>
      <ul class="description__job-criteria-list">
        <li class="description__job-criteria-item">
          <h3 class="description__job-criteria-subheader">Seniority level</h3>
          <span class="description__job-criteria-text">Entry level</span>
        </li>
        <li class="description__job-criteria-item">
          <h3 class="description__job-criteria-subheader">Employment type</h3>
          <span class="description__job-criteria-text">Full-time</span>
        </li>
      </ul>
    HTML
  end

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  describe "#call" do
    let(:result) { step.call(html_content: html) }

    it "extracts title from top-card-layout__title" do
      expect(result[:title]).to eq("Junior Backend Engineer - Typescript")
    end

    it "extracts company from topcard__org-name-link" do
      expect(result[:company]).to eq("Cozycozy")
    end

    it "extracts only the city segment from the bulleted location" do
      expect(result[:city]).to eq("Paris")
    end

    it "maps LinkedIn 'Full-time' to JobOffer EMPLOYMENT_TYPES :full_time" do
      expect(result[:employment_type]).to eq("full_time")
    end

    it "leaves salary fields nil (not exposed on guest pages)" do
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:salary_max_minor]).to be_nil
      expect(result[:salary_currency]).to be_nil
    end

    it "leaves location_mode nil for the enrich step to infer" do
      expect(result[:location_mode]).to be_nil
    end

    it "converts relative posted_at to an ISO8601 timestamp" do
      expect(result[:posted_at]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it "returns description HTML stripped of script and style/class attributes" do
      expect(result[:description_html]).to include("About the role", "Build robust APIs")
      expect(result[:description_html]).not_to include("console.log")
      expect(result[:description_html]).not_to include("style=")
      expect(result[:description_html]).not_to include("class=")
    end
  end

  describe "missing-field tolerance" do
    it "returns nil for missing fields without raising" do
      result = step.call(html_content: "<div>nothing</div>")
      expect(result[:title]).to be_nil
      expect(result[:company]).to be_nil
      expect(result[:city]).to be_nil
      expect(result[:employment_type]).to be_nil
      expect(result[:posted_at]).to be_nil
      expect(result[:description_html]).to be_nil
    end
  end

  describe "employment_type mapping" do
    %w[Full-time Part-time Contract Temporary Internship Apprenticeship].each do |label|
      it "maps '#{label}'" do
        criteria_html = <<~HTML
          <ul><li class="description__job-criteria-item">
            <h3 class="description__job-criteria-subheader">Employment type</h3>
            <span class="description__job-criteria-text">#{label}</span>
          </li></ul>
        HTML
        result = step.call(html_content: criteria_html)
        expect(result[:employment_type]).to eq(
          described_class::EMPLOYMENT_TYPE_MAP[label.downcase]
        )
      end
    end

    it "returns nil for unknown labels" do
      criteria_html = <<~HTML
        <ul><li class="description__job-criteria-item">
          <h3 class="description__job-criteria-subheader">Employment type</h3>
          <span class="description__job-criteria-text">Mystery</span>
        </li></ul>
      HTML
      result = step.call(html_content: criteria_html)
      expect(result[:employment_type]).to be_nil
    end
  end
end
