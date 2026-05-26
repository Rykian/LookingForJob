namespace :indeed do
  # Indeed sits behind Cloudflare Turnstile, which fingerprints every browser
  # Playwright launches (bundled Chromium AND system Chrome via channel:).
  # Reliable workaround: connect to a real Chrome the user runs themselves
  # with remote-debugging enabled, and harvest cookies over CDP. Playwright is
  # only used as a CDP client here, not as a browser launcher.
  desc "Harvest an Indeed session from a running Chrome over CDP (--remote-debugging-port=9222)"
  task login: :environment do
    require "playwright"

    Sourcing::Providers::Indeed::SessionManager # force autoload
    include Sourcing::PlaywrightSupport # for playwright_cli_executable_path

    # Use 127.0.0.1 explicitly: Chrome's remote-debugging endpoint binds to IPv4
    # only, but Playwright resolves "localhost" to ::1 first on macOS.
    cdp_url = ENV.fetch("INDEED_CDP_URL", "http://127.0.0.1:9222")

    puts "=== Indeed session harvester ==="
    puts ""
    puts "Prepare Chrome (one-time, before pressing Enter):"
    puts "  1. Quit all Chrome windows."
    puts "  2. Run in another terminal:"
    puts "       open -na 'Google Chrome' --args \\"
    puts "         --remote-debugging-port=9222 \\"
    puts "         --user-data-dir=\"$HOME/Library/Application Support/Google/Chrome\""
    puts "     (the --user-data-dir flag uses your real Chrome profile)"
    puts "  3. In that Chrome, visit https://fr.indeed.com, pass the Cloudflare check,"
    puts "     sign in if you want, and confirm you reach the search results."
    puts ""
    print "Press Enter here to harvest cookies from #{cdp_url}: "
    STDIN.gets

    Playwright.create(playwright_cli_executable_path:) do |playwright|
      browser = playwright.chromium.connect_over_cdp(cdp_url)
      context = browser.contexts.first
      raise "No browser context exposed at #{cdp_url} (is Chrome running with --remote-debugging-port=9222?)" unless context

      page = context.pages.find { |p| p.url.to_s.include?("indeed.com") } || context.pages.first
      raise "No open page in the connected Chrome. Open fr.indeed.com in a tab first." unless page

      cdp = context.new_cdp_session(page)
      raw = cdp.send_message("Network.getAllCookies")
      raw_cookies = raw["cookies"] || []

      indeed_cookies = raw_cookies.select { |c| c["domain"].to_s.match?(/(?:^|\.)indeed\.com$/i) }
      raise "No Indeed cookies in the connected Chrome. Visit fr.indeed.com first." if indeed_cookies.empty?

      storage_state = {
        "cookies" => indeed_cookies.map { |c| normalize_cookie_for_playwright(c) },
        "origins" => [],
      }

      Sourcing::Providers::Indeed::SessionManager.save(storage_state)

      puts ""
      puts "Saved #{indeed_cookies.size} Indeed cookies to #{Sourcing::Providers::Indeed::SessionManager.path}"
      key_names = %w[cf_clearance CTK INDEED_CSRF_TOKEN SOCK SHOE JSESSIONID]
      present = indeed_cookies.map { |c| c["name"] } & key_names
      if present.any?
        puts "Critical cookies harvested: #{present.join(', ')}"
      else
        puts "Warning: none of #{key_names.join(', ')} were found. The session may be too thin to pass Cloudflare."
      end
    end
  rescue Sourcing::Providers::Indeed::SessionNotFoundError => e
    Sourcing::Providers::Indeed::SessionManager.clear
    raise e.class, e.message
  end

  # Convert a CDP Network.Cookie record to Playwright storage_state cookie shape.
  def normalize_cookie_for_playwright(cdp_cookie)
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
