require "rails_helper"

RSpec.describe Sourcing::Providers::FranceTravail::EnrichStep do
  let(:stub_generator) do
    Class.new {
      def call(**)
        {
          hybrid_remote_days_min_per_week: 2,
          primary_technologies:            ["Ruby on Rails"],
          secondary_technologies:          ["PostgreSQL"],
          offer_language:                  "fr",
          normalized_seniority:            "mid",
          english_level_required:          "professional",
        }
      end
    }.new
  end

  subject(:step) { described_class.new(generator: stub_generator) }

  it "inherits from Sourcing::EnrichStep" do
    expect(step).to be_a(Sourcing::EnrichStep)
  end

  let(:description_html) { "<div>CDI, télétravail partiel 2 jours, salaire 45k, anglais professionnel, poste mid-level.</div>" }
  let(:extracted) do
    {
      title:            "Développeur Ruby (H/F)",
      company:          "ACME Corp",
      location_mode:    "hybrid",
      employment_type:  "PERMANENT",
      salary_min_minor: 45_000,
      salary_max_minor: nil,
      description_html: description_html,
    }
  end

  it "returns all enriched fields with normalized tech names" do
    result = step.call(extracted: extracted)

    expect(result[:hybrid_remote_days_min_per_week]).to eq(2)
    expect(result[:primary_technologies]).to eq(["rubyonrails"])
    expect(result[:secondary_technologies]).to eq(["postgresql"])
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("mid")
    expect(result[:english_level_required]).to eq("professional")
  end

  it "clears hybrid_remote_days when location_mode is not hybrid" do
    result = step.call(extracted: extracted.merge(location_mode: "remote"))
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end

  it "clears hybrid_remote_days when location_mode is nil" do
    result = step.call(extracted: extracted.merge(location_mode: nil))
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end
end
