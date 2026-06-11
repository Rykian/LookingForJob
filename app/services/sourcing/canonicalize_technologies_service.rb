module Sourcing
  class CanonicalizeTechnologiesService
    require "ruby_llm"

    BATCH_SIZE = 500
    COMMON_TECH_COUNT = 120

    # Sorted, unique primary technologies from active offers.
    # Uses only primary_technologies to avoid token consumption & time explosion
    def raw_technologies
      JobOffer.where(disabled: false, rejected: false)
        .pluck(Arel.sql("DISTINCT unnest(primary_technologies)")).compact.sort
    end

    # LLM-canonicalize a single batch of technology names → alias Hash.
    def batch_alias_map(batch)
      parse_llm_response(send_to_llm(build_user_prompt(batch)))
    end

    # Apply the alias map to one offer; persist only if changed. Idempotent.
    def canonicalize_offer!(offer, alias_map)
      primary = canonicalize(offer.primary_technologies, alias_map)
      secondary = canonicalize(offer.secondary_technologies, alias_map)

      return false if primary == offer.primary_technologies && secondary == offer.secondary_technologies

      offer.update_columns(
        primary_technologies: primary,
        secondary_technologies: secondary,
        updated_at: Time.current
      )
      true
    end

    # Write the full alias map to Redis.
    def write_alias_map(alias_map)
      TechnologyStore.write_alias_map(alias_map)
      Rails.logger.info "Wrote full alias map (#{alias_map.count} entries) to Redis"
    end

    # Top canonical technology names by frequency, read from the (post-apply) DB.
    # Unnest happens in a subquery because a set-returning function can't be
    # grouped directly. Same active-offer filter as raw_technologies.
    def top_canonical_technologies
      techs = JobOffer.where(disabled: false, rejected: false)
        .select(Arel.sql("unnest(primary_technologies || secondary_technologies) AS tech"))

      JobOffer
        .from(techs, :techs)
        .group(:tech)
        .order(Arel.sql("COUNT(*) DESC, tech ASC"))
        .limit(COMMON_TECH_COUNT)
        .pluck(:tech)
        .sort
    end

    # Apply alias map to the scoring profile's technology lists; rewrite the
    # JSON file and reload the in-process cache. Idempotent — returns false
    # when nothing changed.
    def canonicalize_scoring_profile!(alias_map)
      profile_path = ScoringProfile::PROFILE_PATH
      raw = JSON.parse(File.read(profile_path))

      primary = canonicalize(raw.dig("technology", "primary") || [], alias_map)
      secondary = canonicalize(raw.dig("technology", "secondary") || [], alias_map)

      return false if primary == raw.dig("technology", "primary") &&
                      secondary == raw.dig("technology", "secondary")

      raw["technology"]["primary"] = primary
      raw["technology"]["secondary"] = secondary

      File.write(profile_path, JSON.pretty_generate(raw))
      ScoringProfile.reload!
      Rails.logger.info "Updated scoring profile technologies to canonical names"
      true
    end

    # Write the common technologies list to Redis.
    def write_common_technologies(names)
      TechnologyStore.write_common_technologies(names)
      Rails.logger.debug "Wrote #{names.count} most-used technologies to Redis"
      names
    end

    private

    # Whitespace-normalized lookup so " Aqua Security" finds "Aqua Security".
    # Unmapped values still get their whitespace cleaned, so messy strings don't
    # survive verbatim in the DB.
    def canonicalize(techs, alias_map)
      techs.map do |t|
        normalized = t.strip.squeeze(" ")
        alias_map[normalized] || alias_map[t] || normalized
      end.uniq
    end

    def build_user_prompt(batch)
      <<~PROMPT
        Here are the technology names to deduplicate:

        #{batch.map { |t| "- #{t}" }.join("\n")}

        Return a JSON object (no array, just an object) where keys are raw names and values are canonical names.
        Example format:
        {
          "node": "Node.js",
          "nodejs": "Node.js",
          "rubyonrails": "Ruby on Rails",
          "rails": "Ruby on Rails",
          "react": "React",
          "typescript": "TypeScript"
        }
      PROMPT
    end

    def send_to_llm(user_prompt)
      llm_config = Sourcing::LlmConfig.from_env
      llm_config.configure!

      system_prompt = build_system_prompt

      RubyLLM
        .chat(model: llm_config.model, provider: llm_config.provider)
        .with_instructions(system_prompt)
        .ask(user_prompt)
    end

    def build_system_prompt
      <<~PROMPT
        You are a technology naming canonicalization expert.
        You receive a list of technology names extracted from job offers (they may have been normalized by removing special characters).
        Group them by the underlying technology they represent, and return a JSON object mapping each raw name to its canonical form.
        Use conventional capitalization (e.g. "Node.js", "C++", "C#", "Ruby on Rails", "PostgreSQL", "TypeScript").

        Versioning rule: Include versions only when they represent a paradigm shift (e.g., Angular 1 vs Angular 2+, Symfony 1 vs Symfony 2+, Python 2 vs Python 3). For incremental updates within the same paradigm (e.g., Angular 16 vs Angular 21, Ruby 2.7 vs Ruby 3.2), use only the base name.

        Names that are already canonical should map to themselves.
        Return ONLY valid JSON with no markdown or prose.
      PROMPT
    end

    def parse_llm_response(response)
      JSON.parse(response.content)
    rescue JSON::ParserError => e
      Rails.logger.error "LLM response was not valid JSON: #{response.content}"
      raise e
    end
  end
end
