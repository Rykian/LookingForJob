module Sourcing
  class DiscoveryStep
    def initialize_playwright(input:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#initialize_playwright must be implemented"
    end

    def crawl_page(input:, playwright_runtime:, page:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#crawl_page must be implemented"
    end

    def crawl_every_pages(input:, playwright_runtime:)
      page = Integer(input.fetch(:page, 1))
      discovered_urls = []

      loop do
        result = crawl_page(input: input, playwright_runtime: playwright_runtime, page: page)
        discovered_urls.concat(Array(result[:discovered_urls]))

        break unless result.fetch(:has_next_page, false)
        page += 1
      end

      { discovered_urls: discovered_urls.uniq }
    end

    def close_playwright(playwright_runtime:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#close_playwright must be implemented"
    end

    def call(input)
      runtime = initialize_playwright(input: input)

      begin
        crawl_every_pages(input: input, playwright_runtime: runtime)
      ensure
        close_playwright(playwright_runtime: runtime)
      end
    end
  end
end
