# frozen_string_literal: true

module Sourcing
  module Providers
    # Harvests a Playwright storage_state from a real Chrome over CDP.
    # Indeed (Cloudflare Turnstile) and WTTJ (AWS WAF) both fingerprint headless
    # browsers and reject every Playwright-launched session. The workaround is
    # identical: the user launches Chrome with --remote-debugging-port=9222, we
    # connect over CDP, and copy cookies into a SessionManager-managed JSON file.
    class CdpSessionHarvester
      include Sourcing::PlaywrightSupport

      DEFAULT_CDP_URL = "http://127.0.0.1:9222"

      def initialize(session_manager:, domain_pattern:, target_url:, critical_cookies:, cdp_url: nil)
        @session_manager = session_manager
        @domain_pattern = domain_pattern
        @target_url = target_url
        @critical_cookies = critical_cookies
        @cdp_url = cdp_url
      end

      def call
        require "playwright"

        print_instructions
        print "Press Enter here to harvest cookies from #{cdp_url}: "
        STDIN.gets

        harvest!
      rescue @session_manager::NOT_FOUND_ERROR => e
        @session_manager.clear
        raise e.class, e.message
      end

      private

      def cdp_url
        @cdp_url ||= ENV.fetch("#{provider_name.upcase}_CDP_URL", DEFAULT_CDP_URL)
      end

      def provider_name
        @session_manager.provider_name
      end

      def chrome_profile_dir
        Rails.root.join("data", "chrome")
      end

      def print_instructions
        puts "=== #{provider_name.capitalize} session harvester ==="
        puts ""
        puts "Prepare Chrome (one-time, before pressing Enter):"
        puts "  1. Quit any Chrome already using this profile dir."
        puts "  2. Run in another terminal:"
        puts "       open -na 'Google Chrome' --args \\"
        puts "         --remote-debugging-port=9222 \\"
        puts "         --user-data-dir=\"#{chrome_profile_dir}\""
        puts "     (dedicated profile dir — won't collide with your everyday Chrome)"
        puts "  3. In that Chrome, visit #{@target_url},"
        puts "     pass any challenge, sign in if needed, and confirm the page loaded."
        puts ""
      end

      def harvest!
        Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path) do |playwright|
          browser = playwright.chromium.connect_over_cdp(cdp_url)
          context = browser.contexts.first
          raise "No browser context exposed at #{cdp_url} (is Chrome running with --remote-debugging-port=9222?)" unless context

          page = pick_page(context)
          cookies = collect_cookies(context, page)
          user_agent = page.evaluate("() => navigator.userAgent")

          @session_manager.save(
            "cookies" => cookies.map { |c| normalize_cookie(c) },
            "origins" => [],
            "userAgent" => user_agent
          )
          report(cookies)
        end
      end

      def pick_page(context)
        host_fragment = URI.parse(@target_url).host
        page = context.pages.find { |p| p.url.to_s.include?(host_fragment) } || context.pages.first
        raise "No open page in the connected Chrome. Open #{@target_url} in a tab first." unless page

        page
      end

      def collect_cookies(context, page)
        cdp = context.new_cdp_session(page)
        raw = cdp.send_message("Network.getAllCookies")
        cookies = (raw["cookies"] || []).select { |c| c["domain"].to_s.match?(@domain_pattern) }
        raise "No #{provider_name} cookies in the connected Chrome. Visit #{@target_url} first." if cookies.empty?

        cookies
      end

      def report(cookies)
        puts ""
        puts "Saved #{cookies.size} #{provider_name} cookies to #{@session_manager.path}"
        present = cookies.map { |c| c["name"] } & @critical_cookies
        if present.any?
          puts "Critical cookies harvested: #{present.join(', ')}"
        else
          puts "Warning: none of #{@critical_cookies.join(', ')} were found. The session may be too thin to pass anti-bot challenges."
        end
      end

      # Convert a CDP Network.Cookie record to Playwright storage_state cookie shape.
      def normalize_cookie(cdp_cookie)
        same_site = cdp_cookie["sameSite"].to_s
        same_site = "Lax" if same_site.empty? || same_site == "None"

        {
          "name" => cdp_cookie["name"],
          "value" => cdp_cookie["value"],
          "domain" => cdp_cookie["domain"],
          "path" => cdp_cookie["path"].to_s.empty? ? "/" : cdp_cookie["path"],
          "expires" => (cdp_cookie["expires"] || -1).to_f,
          "httpOnly" => cdp_cookie["httpOnly"] == true,
          "secure" => cdp_cookie["secure"] == true,
          "sameSite" => same_site,
        }
      end
    end
  end
end
