require "rails_helper"

RSpec.describe Sourcing::Providers::CollectiveWork::EnrichStep do
  let(:stub_generator) do
    Class.new {
      def call(**)
        {
          hybrid_remote_days_min_per_week: 3,
          primary_technologies: ["Ruby", " Ruby ", ""],
          secondary_technologies: ["PostgreSQL"],
          offer_language: "fr",
          normalized_seniority: "senior",
          languages: [{ "language" => "en", "level" => "professional" }],
          posted_by_recruiter: false,
        }
      end
    }.new
  end

  subject(:step) { described_class.new(generator: stub_generator) }

  let(:description_html) do
    "<p>Senior backend engineer working in Ruby on Rails, hybrid in Paris.</p>"
  end

  it "inherits from Sourcing::EnrichStep" do
    expect(step).to be_a(Sourcing::EnrichStep)
  end

  it "returns normalized enrichment fields from the generator" do
    result = step.call(extracted: { description_html: description_html, location_mode: "hybrid" })
    expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
    expect(result[:primary_technologies]).to eq(["Ruby"])
    expect(result[:secondary_technologies]).to eq(["PostgreSQL"])
    expect(result[:offer_language]).to eq("fr")
    expect(result[:normalized_seniority]).to eq("senior")
    expect(result[:languages]).to eq([{ "language" => "en", "level" => "professional" }])
  end

  it "sets hybrid_remote_days_min_per_week to nil for non-hybrid location_mode" do
    result = step.call(extracted: { description_html: description_html, location_mode: "remote" })
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end

  it "sets hybrid_remote_days_min_per_week to nil when location_mode is nil" do
    result = step.call(extracted: { description_html: description_html, location_mode: nil })
    expect(result[:hybrid_remote_days_min_per_week]).to be_nil
  end
end
