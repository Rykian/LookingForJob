module Sourcing
  class AnalyzeStep
    def call(input)
      raise NotImplementedError, "Sourcing::AnalyzeStep is a contract"
    end

    protected

    # Removes style and class attributes from all elements in an HTML string.
    def clean_attributes(html_string)
      return html_string if html_string.nil? || (html_string.respond_to?(:blank?) && html_string.blank?)

      doc = Nokogiri::HTML.fragment(html_string)
      doc.css("*").each do |elem|
        elem.delete("style")
        elem.delete("class")
      end
      doc.to_html.strip
    end
  end
end
