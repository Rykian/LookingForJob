module Sourcing
  class EnrichStep
    # Shared JSON-schema fragment for the languages property of provider
    # response schemas.
    LANGUAGES_SCHEMA = {
      type: "array",
      items: {
        type: "object",
        properties: {
          language: { type: "string", description: "ISO 639-1 code (en, fr, de, ...)" },
          level: { type: "string", enum: %w[not_required basic professional fluent] },
        },
        required: %w[language level],
        additionalProperties: false,
      },
    }.freeze

    LANGUAGES_PROMPT = <<~PROMPT.freeze
      List every language mentioned in the offer with its required level (not_required, basic, professional, fluent) using ISO 639-1 codes.
      Use not_required for languages mentioned but not required (e.g. "a plus").
      Omit languages not mentioned at all.
    PROMPT

    def initialize(llm_config: Sourcing::LlmConfig.from_env, generator: nil)
      @llm_config = llm_config
      @generator = generator || method(:generate_with_ruby_llm)
    end

    def call(input)
      raise NotImplementedError, "Sourcing::EnrichStep is a contract. Override in subclass."
    end

    private

    # Helper to convert HTML descriptions to plain text for LLM input
    def description_html_to_text(description_html)
      return "" if description_html.nil? || description_html.empty?

      Nokogiri::HTML.fragment(description_html).text.gsub(/\s+/, " ").strip
    end

    def generate_with_ruby_llm(model:, provider:, schema:, system:, prompt:)
      @llm_config.configure!

      response = RubyLLM
                 .chat(model: model, provider: provider)
                 .with_instructions(system)
                 .with_schema(schema)
                 .ask(prompt)

      response.content
    end

    # Default: return payload as-is
    def normalize_payload(payload, _extracted)
      payload.respond_to?(:to_h) ? payload.to_h : payload
    end

    protected

    def normalize_languages(arr)
      Array(arr).filter_map do |entry|
        h = entry.respond_to?(:to_h) ? entry.to_h.transform_keys(&:to_s) : nil
        next unless h

        lang = h["language"].to_s.strip.downcase
        level = h["level"].to_s
        next unless JobOffer.valid_language_code?(lang) && JobOffer::LANGUAGE_LEVELS.include?(level)

        { "language" => lang, "level" => level }
      end.uniq { |h| h["language"] }
    end

    def normalize_techs(arr)
      Array(arr).filter_map do |t|
        next unless t.is_a?(String)
        canonical = t.strip.squeeze(" ")
        canonical.empty? ? nil : canonical
      end.uniq
    end

    def canonical_technologies
      @canonical_technologies ||= TechnologyStore.read_alias_map.values.uniq.sort
    end

    def common_technologies
      @common_technologies ||= TechnologyStore.read_common_technologies
    end

    def canonical_technologies_prompt
      techs = common_technologies.empty? ? canonical_technologies : common_technologies
      return "" if techs.empty?

      <<~PROMPT.strip
        Known technologies (use these names when applicable):
        #{techs.join(", ")}

        Versioning rule: Include versions only when they represent a paradigm shift (e.g., Angular 1 vs Angular 2+, Symfony 1 vs Symfony 2+, Python 2 vs Python 3). For incremental updates within the same paradigm (e.g., Angular 16 vs Angular 21), use only the base name.

        If the job requires a technology not in the list, use its conventional name (e.g. "GraphQL", "Docker", "Kubernetes").
      PROMPT
    end
  end
end
