module Sourcing
  class DiscoveryStep
    include PlaywrightSupport

    def supports_work_mode_filter?
      true
    end

    def setup(input:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#setup must be implemented"
    end

    def crawl_page(input:, runtime:, page:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#crawl_page must be implemented"
    end

    def crawl_every_pages(input:, runtime:)
      page = Integer(input.fetch(:page, 1))
      discovered_urls = []

      loop do
        result = crawl_page(input: input, runtime: runtime, page: page)
        discovered_urls.concat(Array(result[:discovered_urls]))

        break unless result.fetch(:has_next_page, false)
        page += 1
      end

      { discovered_urls: discovered_urls.uniq }
    end

    def teardown(runtime:)
      raise NotImplementedError, "Sourcing::DiscoveryStep#teardown must be implemented"
    end

    def call(input)
      runtime = setup(input: input)

      begin
        crawl_every_pages(input: input, runtime: runtime)
      ensure
        teardown(runtime: runtime)
      end
    end
  end
end
