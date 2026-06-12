# frozen_string_literal: true

require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module FreeWork
      # LLM enrichment for fields not reliably present in Free-Work structured data
      # (technologies, seniority, languages, hybrid-day count). Inherits the LLM
      # plumbing (description_html_to_text, canonical_technologies_prompt,
      # generate_with_ruby_llm) from Sourcing::EnrichStep.
      class EnrichStep < Sourcing::EnrichStep
        VERSION = 2

        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are a structured data extractor for Free-Work job offers.
          Return ONLY a valid JSON object matching the provided schema.
          Do not include markdown, prose, or explanations.
        PROMPT

        RESPONSE_SCHEMA = {
          name: "FreeWorkOfferEnrichment",
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
              languages: LANGUAGES_SCHEMA,
              posted_by_recruiter: POSTED_BY_RECRUITER_SCHEMA,
            },
            required: %w[
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
          location_mode = extracted[:location_mode]
          plain_description = description_html_to_text(extracted[:description_html])
          tech_prompt = canonical_technologies_prompt

          <<~PROMPT.strip
            Job title: #{extracted[:title] || "unknown"}
            Company: #{extracted[:company] || "unknown"}
            Location mode: #{location_mode || "unknown"}
            Employment type: #{extracted[:employment_type] || "unknown"}

            Job description text:
            #{plain_description}

            #{POSTED_BY_RECRUITER_PROMPT}
            #{LANGUAGES_PROMPT}
            #{tech_prompt}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          data = super(payload, extracted).transform_keys(&:to_sym)
          location_mode = extracted[:location_mode]

          {
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
