module Sourcing
  class EnrichStep
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
                 .with_schema(schema)
                 .ask("#{system}\n\n#{prompt}")

      response.content
    end

    # Default: return payload as-is
    def normalize_payload(payload, _extracted)
      payload.respond_to?(:to_h) ? payload.to_h : payload
    end

    protected

    def normalize_techs(arr)
      Array(arr).map { |t| t.is_a?(String) ? t.gsub(/[^a-zA-Z]/, "").downcase : t }
    end
  end
end
