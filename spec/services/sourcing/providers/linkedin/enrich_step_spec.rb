require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::EnrichStep do
  def stub_generator(overrides = {})
    payload = {
      location_mode: "hybrid",
      hybrid_remote_days_min_per_week: 2,
      primary_technologies: ["TypeScript", "Node.js"],
      secondary_technologies: ["PostgreSQL"],
      offer_language: "en",
      normalized_seniority: "mid",
      english_level_required: "fluent",
    }.merge(overrides)
    Class.new { define_method(:call) { |**| payload } }.new
  end

  let(:description_html) do
    "<p>Hybrid TypeScript role in Paris with strong English required.</p>"
  end

  it "inherits from Sourcing::EnrichStep" do
    expect(described_class.new(generator: stub_generator)).to be_a(Sourcing::EnrichStep)
  end

  it "lists location_mode in PERSISTED_ATTRIBUTES so EnrichJob persists it" do
    expect(described_class::PERSISTED_ATTRIBUTES).to include(:location_mode)
  end

  it "returns enrichment fields from generator, including location_mode" do
    step = described_class.new(generator: stub_generator)
    result = step.call(extracted: { description_html: description_html })

    expect(result[:location_mode]).to eq("hybrid")
    expect(result[:hybrid_remote_days_min_per_week]).to eq(2)
    expect(result[:primary_technologies]).to eq(%w[typescript nodejs])
    expect(result[:secondary_technologies]).to eq(["postgresql"])
    expect(result[:offer_language]).to eq("en")
    expect(result[:normalized_seniority]).to eq("mid")
    expect(result[:english_level_required]).to eq("fluent")
  end

  it "uses LLM output for location_mode, not analyze's extracted value" do
    step = described_class.new(generator: stub_generator(location_mode: "remote"))
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
    expect(result[:location_mode]).to eq("remote")
  end

  it "nils hybrid_remote_days_min_per_week when LLM returns non-hybrid" do
    step = described_class.new(generator: stub_generator(location_mode: "remote"))
    result = step.call(extracted: { description_html: description_html })
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end

  it "nils hybrid_remote_days_min_per_week when LLM returns nil location_mode" do
    step = described_class.new(generator: stub_generator(location_mode: nil))
    result = step.call(extracted: { description_html: description_html })
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end
end
