require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::EnrichStep do
  let(:llm_config) do
    Sourcing::LlmConfig.new(
      provider: :openai,
      model: "gpt-test-model",
      api_key: "test-key",
      request_timeout: 30,
      max_retries: 3
    )
  end

  let(:generator) do
    lambda do |_input|
      {
        location_mode: "hybrid",
        city: "Paris",
        hybrid_remote_days_min_per_week: 3,
        primary_technologies: ["Ruby on Rails", "PostgreSQL"],
        secondary_technologies: ["Redis"],
        offer_language: "en",
        normalized_seniority: "senior",
        english_level_required: "fluent",
      }
    end
  end

  subject(:step) { described_class.new(llm_config: llm_config, generator: generator) }

  it "maps structured llm output into enrichment fields" do
    extracted = {
      title: "Senior Ruby on Rails Engineer",
      topcard_text: "Paris, Ile-de-France, France · Hybrid · Full-time",
      description_html: <<~HTML,
        <p>3 days remote per week.</p>
        <p>Stack: Ruby on Rails, PostgreSQL, Redis, Sidekiq.</p>
        <p>Fluent English required.</p>
      HTML
    }

    result = step.call(extracted: extracted)
  expect(result[:location_mode]).to eq("hybrid")
  expect(result[:city]).to eq("Paris")

    expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
    expect(result[:primary_technologies]).to include("Ruby on Rails", "PostgreSQL")
    expect(result[:offer_language]).to eq("en")
    expect(result[:normalized_seniority]).to eq("senior")
    expect(result[:english_level_required]).to eq("fluent")
  end

  it "forces hybrid days to nil when offer is not hybrid" do
    result = step.call(
      extracted: {
        title: "Backend Engineer",
        topcard_text: "Paris, Ile-de-France, France · Remote",
        description_html: "<p>2 days remote per week</p>",
      }
    )

  expect(result[:location_mode]).to eq("hybrid")
  expect(result[:hybrid_remote_days_min_per_week]).to eq(3)
  end

  it "forwards configured model and provider to the llm generator" do
    captured = nil
    passthrough_generator = lambda do |input|
      captured = input
      {
        location_mode: "hybrid",
        city: "Paris",
        hybrid_remote_days_min_per_week: nil,
        primary_technologies: [],
        secondary_technologies: [],
        offer_language: nil,
        normalized_seniority: nil,
        english_level_required: nil,
      }
    end

    step = described_class.new(llm_config: llm_config, generator: passthrough_generator)
    step.call(extracted: { title: "Backend Engineer", topcard_text: "Paris · Remote", description_html: "<p>Text</p>" })

    expect(captured[:model]).to eq("gpt-test-model")
    expect(captured[:provider]).to eq(:openai)
  end
end
