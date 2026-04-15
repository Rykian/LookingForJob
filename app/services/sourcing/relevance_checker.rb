require "set"

module Sourcing
  class RelevanceChecker
    NORMALIZATION_ALIASES = {
      /c\+\+/i => " cpp ",
      /c#/i => " csharp ",
      /\.net/i => " dotnet ",
      /node\.js/i => " nodejs ",
    }.freeze

    def call(keywords, html_content)
      normalized_keywords = normalize_keywords(keywords)
      return true if normalized_keywords.empty?

      normalized_text = normalize_text(Nokogiri::HTML.fragment(html_content.to_s).text)
      return false if normalized_text.blank?

      tokens = normalized_text.split.to_set
      padded_text = " #{normalized_text} "

      normalized_keywords.any? do |keyword|
        if keyword.include?(" ")
          padded_text.include?(" #{keyword} ")
        else
          tokens.include?(keyword)
        end
      end
    end

    private

    # Normalize keywords by applying symbol aliases, downcasing, and removing punctuation.
    def normalize_keywords(keywords)
      Array(keywords)
        .flat_map { |keyword| expand_keyword_variants(keyword.to_s) }
        .map { |keyword| normalize_text(keyword) }
        .reject(&:blank?)
        .uniq
    end

    # Expand keyword variants based on defined normalization aliases. For example, "C#" would expand to both "csharp" and "c#".
    def expand_keyword_variants(keyword)
      return [] if keyword.blank?

      normalized_keyword = keyword.strip
      variants = [normalized_keyword]

      NORMALIZATION_ALIASES.each do |pattern, canonical|
        variants << canonical.strip if normalized_keyword.match?(pattern)
      end

      variants
    end

    # Normalize text by applying symbol aliases, downcasing, and removing punctuation. This ensures consistent matching against normalized keywords.
    def normalize_text(value)
      normalized_value = value.to_s
      NORMALIZATION_ALIASES.each do |pattern, canonical|
        normalized_value = normalized_value.gsub(pattern, canonical)
      end

      normalized_value
        .downcase
        .gsub(/[^a-z\s]/, " ")
        .gsub(/\s+/, " ")
        .strip
    end
  end
end
