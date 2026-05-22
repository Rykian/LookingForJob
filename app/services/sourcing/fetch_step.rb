module Sourcing
  class FetchStep
    include PlaywrightSupport

    def initialize(fetcher: nil)
      @fetcher = fetcher || method(:fetch_page)
    end

    def call(input)
      @fetcher.call(url: input.fetch(:url))
    end

    protected

    def fetch_page(url:)
      raise NotImplementedError, "Sourcing::FetchStep subclasses must implement #fetch_page"
    end
  end
end
