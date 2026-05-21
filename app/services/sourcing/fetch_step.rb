module Sourcing
  class FetchStep
    include PlaywrightSupport

    def initialize(fetcher: nil)
      @fetcher = fetcher || method(:fetch_with_playwright)
    end

    def call(input)
      @fetcher.call(url: input.fetch(:url))
    end

    protected

    def fetch_with_playwright(url:)
      raise NotImplementedError, "Sourcing::FetchStep subclasses must implement #fetch_with_playwright"
    end
  end
end
