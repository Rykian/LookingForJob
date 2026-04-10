module Sourcing
  module PlaywrightSupport
    DEFAULT_VIEWPORT = { width: 1366, height: 768 }.freeze
    DEFAULT_TIMEZONE_ID = "Europe/Paris"
    DEFAULT_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36".freeze

    private

    def playwright_cli_executable_path
      version = Gem.loaded_specs.fetch("playwright-ruby-client").version.to_s
      "npx -y playwright@#{version}"
    end

    def default_context_options(locale:, storage_state: nil)
      options = {
        viewport: DEFAULT_VIEWPORT,
        locale: locale,
        timezoneId: DEFAULT_TIMEZONE_ID,
        userAgent: DEFAULT_USER_AGENT,
      }
      options[:storageState] = storage_state if storage_state
      options
    end

    def with_playwright_page(url:, locale:, storage_state: nil)
      require "playwright"

      playwright = nil
      browser = nil
      context = nil
      page_obj = nil

      Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path) do |runtime|
        playwright = runtime
        browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
        context = browser.new_context(**default_context_options(locale: locale, storage_state: storage_state))
        page_obj = context.new_page
        page_obj.goto(url, waitUntil: "domcontentloaded")

        return yield(page_obj)
      end
    ensure
      begin
        page_obj&.close
      rescue StandardError
        nil
      end
      begin
        context&.close
      rescue StandardError
        nil
      end
      begin
        browser&.close
      rescue StandardError
        nil
      end
    end

    def wait_for_any_selector(page_obj:, selectors:, timeout_ms:, wait_options: {})
      combined = selectors.join(", ")
      page_obj.wait_for_selector(combined, timeout: timeout_ms, **wait_options)
      # Return whichever individual selector is now present so callers get consistent behaviour.
      selectors.find { |s| page_obj.query_selector(s) } || combined
    rescue StandardError
      nil
    end

    def click_first_selector(page_obj:, selectors:)
      selectors.each do |selector|
        button = page_obj.query_selector(selector)
        next unless button

        button.click
        return selector
      rescue StandardError
        next
      end

      nil
    end

    def ensure_basic_html_content!(provider_name:, url:, html:)
      normalized = html.to_s.strip
      raise "#{provider_name} fetch produced empty_html for #{url}" if normalized.empty?

      compact_html = normalized.downcase.gsub(/\s+/, "")
      return unless compact_html == "<html><head></head><body></body></html>" || compact_html == "<html><body></body></html>"

      raise "#{provider_name} fetch produced shell_html for #{url}"
    end
  end
end
