# frozen_string_literal: true

require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module Linkedin
      # LLM-backed inference of fields LinkedIn guest pages do not expose:
      # location_mode (remote/hybrid/on-site), salary, technologies, language,
      # normalized seniority, English level. Mirrors the cadremploi enrich schema
      # for consistency across providers.
      class EnrichStep < Sourcing::EnrichStep
        VERSION = 2

        # LinkedIn guest pages don't expose location_mode, so we infer it here in addition
        # to the default enriched attributes. EnrichJob reads this constant when slicing
        # which fields to persist.
        PERSISTED_ATTRIBUTES = %i[
          location_mode
          hybrid_remote_days_min_per_week
          primary_technologies
          secondary_technologies
          offer_language
          normalized_seniority
          english_level_required
        ].freeze

        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are a structured data extractor for LinkedIn job offers.
          Return ONLY a valid JSON object matching the provided schema.
          Do not include markdown, prose, or explanations.
        PROMPT

        RESPONSE_SCHEMA = {
          name: "LinkedinOfferEnrichment",
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
              english_level_required: {
                type: ["string", "null"],
                enum: ["none", "basic", "professional", "fluent", nil],
              },
            },
            required: %w[
              location_mode
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

        def call(input)
          extracted = input.fetch(:extracted)
          payload = @generator.call(
            model:    @llm_config.model,
            provider: @llm_config.provider,
            schema:   RESPONSE_SCHEMA,
            system:   SYSTEM_PROMPT,
            prompt:   build_user_prompt(extracted)
          )

          normalize_payload(payload, extracted)
        end

        private

        def build_user_prompt(extracted)
          plain_description = description_html_to_text(extracted[:description_html])
          tech_prompt = canonical_technologies_prompt

          <<~PROMPT.strip
            Job title: #{extracted[:title] || "unknown"}
            Company: #{extracted[:company] || "unknown"}
            City: #{extracted[:city] || "unknown"}
            Employment type: #{extracted[:employment_type] || "unknown"}

            Job description text:
            #{plain_description}

            #{tech_prompt}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          data = super(payload, extracted).transform_keys(&:to_sym)
          # LLM is the source of truth for location_mode on LinkedIn (guest HTML doesn't expose it).
          location_mode = data[:location_mode]

          {
            location_mode:                   location_mode || "on-site",
            hybrid_remote_days_min_per_week: location_mode == "hybrid" ? data[:hybrid_remote_days_min_per_week] : nil,
            primary_technologies:            normalize_techs(data[:primary_technologies]),
            secondary_technologies:          normalize_techs(data[:secondary_technologies]),
            offer_language:                  data[:offer_language],
            normalized_seniority:            data[:normalized_seniority],
            english_level_required:          data[:english_level_required],
          }
        end
      end
    end
  end
end
