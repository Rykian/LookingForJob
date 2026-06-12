require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::EnrichStep do
  let(:llm_payload) do
    {
      location_mode: "remote",
      hybrid_remote_days_min_per_week: 3,
      primary_technologies: ["Ruby on Rails"],
      secondary_technologies: ["Redis"],
      offer_language: "fr",
      normalized_seniority: "junior",
      languages: [{ "language" => "en", "level" => "professional" }],
      posted_by_recruiter: false,
    }
  end

  let(:stub_generator) do
    payload = llm_payload
    Class.new {
      define_method(:call) { |**| payload }
    }.new
  end

  subject(:step) { described_class.new(generator: stub_generator) }

  let(:description_html) { "<div>CDI, télétravail partiel possible, salaire 40k-50k, anglais professionnel requis, poste junior, français courant.</div>" }

  it "inherits from Sourcing::EnrichStep" do
    expect(step).to be_a(Sourcing::EnrichStep)
  end

  it "keeps metadata-provided location_mode and ignores the LLM's value" do
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
    expect(result[:primary_technologies]).to eq(["Ruby on Rails"])
    expect(result[:secondary_technologies]).to eq(["Redis"])
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("junior")
    expect(result[:languages]).to eq([{ "language" => "en", "level" => "professional" }])
  end

  it "falls back to LLM-inferred location_mode when metadata is missing" do
    result = step.call(extracted: { description_html: description_html, location_mode: nil })
    expect(result[:location_mode]).to eq("remote")
  end

  it "treats blank string metadata as missing" do
    result = step.call(extracted: { description_html: description_html, location_mode: "" })
    expect(result[:location_mode]).to eq("remote")
  end

  it "nils hybrid_remote_days_min_per_week unless the final location_mode is hybrid" do
    result = step.call(extracted: { description_html: description_html, location_mode: nil })
    expect(result[:location_mode]).to eq("remote")
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end

  it "exposes PERSISTED_ATTRIBUTES including location_mode" do
    expect(described_class::PERSISTED_ATTRIBUTES).to include(:location_mode)
  end

  it "passes posted_by_recruiter through" do
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
    expect(result[:posted_by_recruiter]).to be(false)
  end

  context "when the LLM flags a recruiting intermediary" do
    let(:llm_payload) { super().merge(posted_by_recruiter: true) }

    it "returns posted_by_recruiter true" do
      result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
      expect(result[:posted_by_recruiter]).to be(true)
    end
  end
end
