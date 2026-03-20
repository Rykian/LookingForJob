require "nokogiri"
require "ruby_llm"

module Sourcing
  module Providers
    module Linkedin
      class EnrichStep < Sourcing::EnrichStep
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
                maximum: 5
              },
              primary_technologies: {
                type: ["array", "null"],
                items: { type: "string" }
              },
              secondary_technologies: {
                type: ["array", "null"],
                items: { type: "string" }
              },
              offer_language: {
                type: ["string", "null"],
                enum: ["fr", "en", "other", nil]
              },
              normalized_seniority: {
                type: ["string", "null"],
                enum: ["intern", "junior", "mid", "senior", "staff", nil]
              },
              english_level_required: {
                type: ["string", "null"],
                enum: ["none", "basic", "professional", "fluent", nil]
              }
            },
            required: %w[
              hybrid_remote_days_min_per_week
              primary_technologies
              secondary_technologies
              offer_language
              normalized_seniority
              english_level_required
            ],
            additionalProperties: false
          },
          strict: true
        }.freeze

        def initialize(llm_config: Sourcing::LlmConfig.from_env, generator: nil)
          @llm_config = llm_config
          @generator = generator || method(:generate_with_ruby_llm)
        end

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

        def generate_with_ruby_llm(model:, provider:, schema:, system:, prompt:)
          @llm_config.configure!

          response = RubyLLM
                     .chat(model: model, provider: provider)
                     .with_schema(schema)
                     .ask("#{system}\n\n#{prompt}")

          response.content
        end

        def build_user_prompt(extracted)
          plain_description = description_html_to_text(extracted[:description_html])

          <<~PROMPT
            Job title: #{extracted[:title] || "unknown"}
            Company: #{extracted[:company] || "unknown"}
            Remote status: #{extracted[:remote] || "unknown"}

            Job description text:
            #{plain_description}
          PROMPT
        end

        def normalize_payload(payload, extracted)
          data = payload.respond_to?(:to_h) ? payload.to_h : payload
          data = data.transform_keys(&:to_sym)

          {
            hybrid_remote_days_min_per_week: extracted[:remote] == "hybrid" ? data[:hybrid_remote_days_min_per_week] : nil,
            primary_technologies: data[:primary_technologies],
            secondary_technologies: data[:secondary_technologies],
            offer_language: data[:offer_language],
            normalized_seniority: data[:normalized_seniority],
            english_level_required: data[:english_level_required]
          }
        end

        def description_html_to_text(description_html)
          return "" if description_html.nil? || description_html.empty?

          Nokogiri::HTML.fragment(description_html).text.gsub(/\s+/, " ").strip
        end
      end
    end
  end
end
