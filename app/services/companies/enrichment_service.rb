require "ruby_llm"

module Companies
  # LLM-backed company profile: description, website, official name and
  # recruiter/final-client hints, generated from model knowledge. Guarded by a
  # `known` escape hatch so unknown companies are left untouched.
  class EnrichmentService
    VERSION = 1

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You provide factual profiles of companies for a job-hunting tool.
      Only use knowledge you are confident about.
      IMPORTANT: If you do not reliably know this company, set known to false
      and every nullable field to null.
      Provide official_name only when you are certain of the company's official
      name, otherwise null. The description is 2-4 sentences: what the company
      does, sector, notable facts. website is the main corporate website URL.
      is_recruiter is true when the company is a staffing agency, recruitment
      firm or ESN/consulting firm placing consultants; is_final_client is true
      when it hires for its own teams.
      Return ONLY a valid JSON object matching the provided schema.
    PROMPT

    RESPONSE_SCHEMA = {
      name: "CompanyEnrichment",
      schema: {
        type: "object",
        properties: {
          known: { type: "boolean" },
          official_name: { type: ["string", "null"] },
          description: { type: ["string", "null"] },
          website: { type: ["string", "null"] },
          is_recruiter: { type: "boolean" },
          is_final_client: { type: "boolean" },
        },
        required: %w[known official_name description website is_recruiter is_final_client],
        additionalProperties: false,
      },
      strict: true,
    }.freeze

    def initialize(llm_config: Sourcing::LlmConfig.from_env, generator: nil)
      @llm_config = llm_config
      @generator = generator || method(:generate_with_ruby_llm)
    end

    def call(company)
      payload = @generator.call(
        model: @llm_config.company_model,
        provider: @llm_config.provider,
        schema: RESPONSE_SCHEMA,
        system: SYSTEM_PROMPT,
        prompt: build_user_prompt(company)
      )
      data = (payload.respond_to?(:to_h) ? payload.to_h : payload).deep_stringify_keys

      attrs = { enriched_at: Time.current, enrichment_version: VERSION }
      attrs[:posts_as_recruiter] = true if data["is_recruiter"] && !company.posts_as_recruiter
      attrs[:posts_as_final_client] = true if data["is_final_client"] && !company.posts_as_final_client

      if data["known"]
        attrs[:description] = data["description"] if data["description"].present?
        attrs[:website] = normalize_website(data["website"]) if data["website"].present?
      end

      company.update!(attrs)
      apply_official_name(company, data["official_name"]) if data["known"]
      company
    end

    private

    def build_user_prompt(company)
      offers = company.job_offers.order(created_at: :desc).limit(5).pluck(:title, :city)
      offers_context = offers.filter_map do |title, city|
        next if title.blank?

        city.present? ? "- #{title} (#{city})" : "- #{title}"
      end

      prompt = "Company name: #{company.name}"
      if offers_context.any?
        prompt += "\n\nJob offers this company posted (for disambiguation):\n#{offers_context.join("\n")}"
      end
      prompt
    end

    # Renaming flows through AliasManager so the official name always has an
    # alias. Skipped when the name belongs to another company: an automated
    # call must never merge two companies — that's a human decision in the
    # aliases editor.
    def apply_official_name(company, official_name)
      return if official_name.blank?

      normalized = Company.normalize(official_name)
      return if normalized.blank? || normalized == Company.normalize(company.name)

      owner = CompanyAlias.find_by(normalized_name: normalized)&.company
      return if owner && owner != company

      Companies::AliasManager.new.rename!(company: company, name: official_name)
    end

    def normalize_website(raw)
      url = raw.to_s.strip
      return nil if url.empty?

      url = "https://#{url}" unless url.match?(%r{\Ahttps?://}i)
      url
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
  end
end
