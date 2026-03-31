require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::EnrichStep do
  let(:stub_generator) do
    Class.new {
      def extract_json(**)
        {
          remote_policy: "hybrid",
          contract_type: "CDI",
          salary_range: "40k-50k",
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
    result = step.call(description_html: description_html)
    expect(result[:remote_policy]).to eq("hybrid")
    expect(result[:contract_type]).to eq("CDI")
    expect(result[:salary_range]).to eq("40k-50k")
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("junior")
    expect(result[:english_level_required]).to eq("professional")
  end

  # TODO: Add integration tests for enriching WTTJ job details
end
