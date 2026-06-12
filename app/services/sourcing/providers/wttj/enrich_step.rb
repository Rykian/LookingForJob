require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module Wttj
      class EnrichStep < Sourcing::EnrichStep
        VERSION = 5

        # Persisted on the JobOffer by EnrichJob. Includes location_mode so we
        # can backfill it when the AnalyzeStep couldn't extract it from metadata.
        PERSISTED_ATTRIBUTES = %i[
          location_mode
          hybrid_remote_days_min_per_week
          primary_technologies
          secondary_technologies
          offer_language
          normalized_seniority
          languages
          posted_by_recruiter
        ].freeze

        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are a structured data extractor for Welcome to the Jungle job offers.
          Return ONLY a valid JSON object matching the provided schema.
          Do not include markdown, prose, or explanations.
          When the metadata-provided location mode is "unknown", infer it from the
          description (look for télétravail/remote/hybride/sur site cues).
        PROMPT

        RESPONSE_SCHEMA = {
          name: "WttjOfferEnrichment",
          schema: {
            type: "object",
            properties: {
              location_mode: {
                type: ["string", "null"],
                enum: ["remote", "hybrid", "on-site", nil],
              },
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
              languages: LANGUAGES_SCHEMA,
              posted_by_recruiter: POSTED_BY_RECRUITER_SCHEMA,
            },
            required: %w[
              location_mode
              hybrid_remote_days_min_per_week
              primary_technologies
              secondary_technologies
              offer_language
              normalized_seniority
              languages
              posted_by_recruiter
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

        def build_user_prompt(extracted)
          plain_description = description_html_to_text(extracted[:description_html])
          tech_prompt = canonical_technologies_prompt

          <<~PROMPT.strip
            Job title: #{extracted[:title] || "unknown"}
            Company: #{extracted[:company] || "unknown"}
            Location mode (from metadata): #{extracted[:location_mode] || "unknown"}

            Job description text:
            #{plain_description}

            #{POSTED_BY_RECRUITER_PROMPT}
            #{LANGUAGES_PROMPT}
            #{tech_prompt}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          data = super(payload, extracted).transform_keys(&:to_sym)
          location_mode = extracted[:location_mode].presence || data[:location_mode] || :on_site

          {
            location_mode:,
            hybrid_remote_days_min_per_week: location_mode == "hybrid" ? data[:hybrid_remote_days_min_per_week] : nil,
            primary_technologies: normalize_techs(data[:primary_technologies]),
            secondary_technologies: normalize_techs(data[:secondary_technologies]),
            offer_language: data[:offer_language],
            normalized_seniority: data[:normalized_seniority],
            languages: normalize_languages(data[:languages]),
            posted_by_recruiter: data[:posted_by_recruiter] == true,
          }
        end
      end
    end
  end
end
