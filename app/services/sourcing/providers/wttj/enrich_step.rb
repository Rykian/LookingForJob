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

        # Inherit initialize and generate_with_ruby_llm from parent

        def call(input)
          extracted = input.fetch(:extracted, nil)
          payload = @generator.call(
            model: @llm_config.model,
            provider: @llm_config.provider,
            schema: RESPONSE_SCHEMA,
            system: SYSTEM_PROMPT,
            prompt: build_user_prompt(extracted)
          )

          normalize_payload(payload, extracted)
        end
        def build_user_prompt(extracted)
          plain_description = description_html_to_text(extracted[:description_html])
          <<~PROMPT
            Job title: #{extracted[:title] || "unknown"}
            Company: #{extracted[:company] || "unknown"}
            Location mode: #{extracted[:location_mode] || "unknown"}

            Job description text:
            #{plain_description}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          data = super(payload, extracted).transform_keys(&:to_sym)
          {
            remote_policy: data[:remote_policy],
            contract_type: data[:contract_type],
            salary_range: data[:salary_range],
            offer_language: data[:offer_language],
            normalized_seniority: data[:normalized_seniority],
            english_level_required: data[:english_level_required],
          }
        end
      end
    end
  end
end
