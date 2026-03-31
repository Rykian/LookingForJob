require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module Wttj
      class EnrichStep < Sourcing::EnrichStep
        VERSION = 1

        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are a structured data extractor for Welcome to the Jungle job offers.
          Return ONLY a valid JSON object matching the provided schema.
          Do not include markdown, prose, or explanations.
        PROMPT

        RESPONSE_SCHEMA = {
          name: "WttjOfferEnrichment",
          schema: {
            type: "object",
            properties: {
              remote_policy: { type: ["string", "null"] },
              contract_type: { type: ["string", "null"] },
              salary_range: { type: ["string", "null"] },
              offer_language: {
                type: ["string", "null"],
                enum: ["fr", "en", "other", nil],
              },
              normalized_seniority: {
                type: ["string", "null"],
                enum: ["intern", "junior", "mid", "senior", "staff", nil],
              },
              english_level_required: {
                type: ["string", "null"],
                enum: ["none", "basic", "professional", "fluent", nil],
              },
            },
            required: %w[
              remote_policy
              contract_type
              salary_range
              offer_language
              normalized_seniority
              english_level_required
            ],
            additionalProperties: false,
          },
          strict: true,
        }.freeze

        def initialize(llm_config: Sourcing::LlmConfig.from_env, generator: nil)
          @llm_config = llm_config
          @generator = generator || method(:generate_with_ruby_llm)
        end

        def call(input)
          extracted = input.fetch(:extracted, nil)
          description = input[:description_html] || ""
          payload = @generator.call(
            model: @llm_config.model,
            provider: @llm_config.provider,
            schema: RESPONSE_SCHEMA,
            system: SYSTEM_PROMPT,
            prompt: build_user_prompt(description, extracted)
          )

          normalize_payload(payload, extracted)
        end

        private

        def generate_with_ruby_llm(model:, provider:, schema:, system:, prompt:)
          @llm_config.configure!

          response = RubyLLM
                     .chat(model: model, provider: provider)
                     .with_schema(schema)
                     .ask("#{system}\n\n#{prompt}")

          response.content
        end

        def build_user_prompt(description, extracted)
          <<~PROMPT
            Extract the following fields from the job offer description below. Use the schema provided. If a field is not present, return null for that field.

            Job offer description:
            #{description}

            Extracted fields (if any):
            #{extracted.inspect}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          # Optionally merge or post-process as needed
          payload
        end
      end
    end
  end
end
