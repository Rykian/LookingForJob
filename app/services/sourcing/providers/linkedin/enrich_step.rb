require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module Linkedin
      class EnrichStep < Sourcing::EnrichStep
        VERSION = 1

        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are a structured data extractor for job offers.
          Return ONLY a valid JSON object matching the provided schema.
          Do not include markdown, prose, or explanations.
        PROMPT

        RESPONSE_SCHEMA = {
          name: "LinkedinOfferEnrichment",
          schema: {
            type: "object",
            properties: {
              hybrid_remote_days_min_per_week: {
                type: ["integer", "null"],
                minimum: 1,
                maximum: 5,
              },
              primary_technologies: {
                type: ["array", "null"],
                items: { type: "string" },
              },
              secondary_technologies: {
                type: ["array", "null"],
                items: { type: "string" },
              },
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
              hybrid_remote_days_min_per_week
              primary_technologies
              secondary_technologies
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
          extracted = input.fetch(:extracted)
          payload = @generator.call(
            model: @llm_config.model,
            provider: @llm_config.provider,
            schema: RESPONSE_SCHEMA,
            system: SYSTEM_PROMPT,
            prompt: build_user_prompt(extracted)
          )

          normalize_payload(payload, extracted)
        end

        private

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
            hybrid_remote_days_min_per_week: extracted[:location_mode] == "hybrid" ? data[:hybrid_remote_days_min_per_week] : nil,
            primary_technologies: technology_labels(data[:primary_technologies]),
            secondary_technologies: technology_labels(data[:secondary_technologies]),
            offer_language: data[:offer_language],
            normalized_seniority: data[:normalized_seniority],
            english_level_required: data[:english_level_required],
          }
        end

        def technology_labels(values)
          Array(values).filter_map do |value|
            next value unless value.is_a?(String)

            label = value.strip
            label unless label.empty?
          end.uniq
        end
      end
    end
  end
end
