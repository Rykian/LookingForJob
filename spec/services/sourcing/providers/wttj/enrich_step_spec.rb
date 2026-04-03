require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::EnrichStep do
  let(:stub_generator) do
    Class.new {
      def call(**)
        {
          hybrid_remote_days_min_per_week: 3,
          primary_technologies: ["Ruby on Rails"],
          secondary_technologies: ["Redis"],
          offer_language: "fr",
          normalized_seniority: "junior",
          english_level_required: "professional",
        }
      end
    }.new
  end

  subject(:step) { described_class.new(generator: stub_generator) }

  let(:description_html) { "<div>CDI, télétravail partiel possible, salaire 40k-50k, anglais professionnel requis, poste junior, français courant.</div>" }

  it "inherits from Sourcing::EnrichStep" do
    expect(step).to be_a(Sourcing::EnrichStep)
  end

  it "extracts enrichment fields from description" do
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
    expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
    expect(result[:primary_technologies]).to eq(["rubyonrails"])
    expect(result[:secondary_technologies]).to eq(["redis"])
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("junior")
    expect(result[:english_level_required]).to eq("professional")
  end

  # TODO: Add integration tests for enriching WTTJ job details
end
