require "rails_helper"

RSpec.describe Sourcing::Providers::Apec::EnrichStep do
  let(:stub_generator) do
    Class.new {
      def call(**)
        {
          hybrid_remote_days_min_per_week: 3,
          primary_technologies: ["Ruby on Rails"],
          secondary_technologies: ["PostgreSQL"],
          offer_language: "fr",
          normalized_seniority: "senior",
          english_level_required: "professional",
        }
      end
    }.new
  end

  subject(:step) { described_class.new(generator: stub_generator) }

  let(:description_html) do
    "<p>Poste senior Ruby on Rails en teletravail partiel.</p>"
  end

  it "inherits from Sourcing::EnrichStep" do
    expect(step).to be_a(Sourcing::EnrichStep)
  end

  it "returns normalized enrichment payload" do
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })

    expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
    expect(result[:primary_technologies]).to eq(["rubyonrails"])
    expect(result[:secondary_technologies]).to eq(["postgresql"])
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("senior")
    expect(result[:english_level_required]).to eq("professional")
  end

  it "sets remote days to nil when not hybrid" do
    result = step.call(extracted: { description_html: description_html, location_mode: "remote" })
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end
end
