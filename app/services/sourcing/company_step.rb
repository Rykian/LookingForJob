require "nokogiri"
require "ruby_llm"

module Sourcing
  # Guesses the final client behind recruiter-posted offers. The recruiter
  # classification itself comes from the enrich step (posted_by_recruiter on
  # the offer); direct-employer offers skip the LLM entirely. Falls back to
  # classifying here when the flag is nil (offer enriched before the flag
  # existed). Links the offer to its posting Company (and final Company when
  # confident) and records sticky posts_as_recruiter / posts_as_final_client
  # votes on companies.
  class CompanyStep
    VERSION = 1
    CONFIDENCE_THRESHOLD = 0.8
    MAX_GUESSES = 5

    Result = Struct.new(:company_id, :posted_by_recruiter, :final_client_guesses, :final_company_id, keyword_init: true)

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You classify job offers posted on job boards.
      Decide whether the posting company is a recruiting intermediary (staffing
      agency, recruitment firm, ESN / consulting company placing consultants at
      clients) or the company that will actually employ the candidate.
      Treat posting names that are not real organization names as intermediaries
      too: salary or remote fragments ("$55/hr Remote"), generic job-board
      categories ("Collectivité territoriale (mairie / département / région)"),
      "Confidential" and the like — the real employer must then be guessed from
      the text.
      If it is an intermediary, list up to #{MAX_GUESSES} candidate final clients that are
      named in the text or can be reasonably inferred from it (sector, location,
      product hints), each with a confidence between 0 and 1 and a short reasons
      text explaining the clues.
      Each guess name must be the exact official organization name — never a
      description, a category, or a text fragment. For public entities, name the
      exact entity (e.g. "Mairie de Lyon", "Département du Rhône",
      "Région Île-de-France", "Ministère de l'Économie et des Finances").
      Return an empty list when the poster is the final employer or when there
      is no usable signal.
      Return ONLY a valid JSON object matching the provided schema.
    PROMPT

    RESPONSE_SCHEMA = {
      name: "OfferCompanyClassification",
      schema: {
        type: "object",
        properties: {
          posted_by_recruiter: {
            type: "boolean",
            description: "true when the posting company is a staffing agency, recruitment firm or ESN posting on behalf of another company",
          },
          final_client_guesses: {
            type: "array",
            maxItems: MAX_GUESSES,
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                confidence: { type: "number", minimum: 0, maximum: 1 },
                reasons: { type: "string", description: "short justification for this guess" },
              },
              required: %w[name confidence reasons],
              additionalProperties: false,
            },
          },
        },
        required: %w[posted_by_recruiter final_client_guesses],
        additionalProperties: false,
      },
      strict: true,
    }.freeze

    def self.call(offer:)
      new.call(offer: offer)
    end

    def initialize(llm_config: Sourcing::LlmConfig.from_env, generator: nil)
      @llm_config = llm_config
      @generator = generator || method(:generate_with_ruby_llm)
    end

    def call(offer:)
      return Result.new(company_id: nil, posted_by_recruiter: nil, final_client_guesses: [], final_company_id: nil) if offer.company_name.blank?

      company = Company.find_or_create_by_name!(offer.company_name)

      # The enrich step already classified this offer as posted by a direct
      # employer — no final client to guess, skip the LLM call entirely.
      if offer.posted_by_recruiter == false
        company.update!(posts_as_final_client: true) unless company.posts_as_final_client
        return Result.new(company_id: company.id, posted_by_recruiter: false, final_client_guesses: [], final_company_id: nil)
      end

      payload = @generator.call(
        model: @llm_config.company_model,
        provider: @llm_config.provider,
        schema: RESPONSE_SCHEMA,
        system: SYSTEM_PROMPT,
        prompt: build_user_prompt(offer)
      )
      data = (payload.respond_to?(:to_h) ? payload.to_h : payload).deep_stringify_keys

      # Reached with offer flag true (enrich classified a recruiter) or nil
      # (legacy enrich version) — the enrich-time flag wins over this call's.
      posted_by_recruiter = offer.posted_by_recruiter.nil? ? data["posted_by_recruiter"] == true : true
      guesses = normalize_guesses(data["final_client_guesses"])
      final_company = resolve_final_company(company, posted_by_recruiter, guesses)

      record_company_votes(company, posted_by_recruiter, final_company)

      Result.new(
        company_id: company.id,
        posted_by_recruiter: posted_by_recruiter,
        final_client_guesses: guesses,
        final_company_id: final_company&.id
      )
    end

    private

    def build_user_prompt(offer)
      plain_description = description_html_to_text(offer.description_html)

      <<~PROMPT.strip
        Job title: #{offer.title.presence || "unknown"}
        Posting company: #{offer.company_name}

        Job description text:
        #{plain_description}
      PROMPT
    end

    def normalize_guesses(raw)
      Array(raw).filter_map do |entry|
        h = entry.respond_to?(:to_h) ? entry.to_h.transform_keys(&:to_s) : nil
        next unless h

        name = h["name"].to_s.strip
        confidence = h["confidence"]
        next if name.empty? || !confidence.is_a?(Numeric)

        {
          "name" => name,
          "confidence" => confidence.to_f.clamp(0.0, 1.0),
          "reasons" => h["reasons"].to_s.strip,
        }
      end.sort_by { |g| -g["confidence"] }.first(MAX_GUESSES)
    end

    def resolve_final_company(company, posted_by_recruiter, guesses)
      return nil unless posted_by_recruiter

      best = guesses.first
      return nil unless best && best["confidence"] >= CONFIDENCE_THRESHOLD
      # Never self-link: a guess resolving to the posting company is no signal.
      return nil if Company.normalize(best["name"]) == Company.normalize(company.name)

      Company.find_or_create_by_name!(best["name"])
    end

    # Sticky votes: flags are only ever set, never unset — an ESN seen posting
    # both ways ends up with both flags.
    def record_company_votes(company, posted_by_recruiter, final_company)
      if posted_by_recruiter
        company.update!(posts_as_recruiter: true) unless company.posts_as_recruiter
      else
        company.update!(posts_as_final_client: true) unless company.posts_as_final_client
      end

      return unless final_company
      final_company.update!(posts_as_final_client: true) unless final_company.posts_as_final_client
    end

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
  end
end
