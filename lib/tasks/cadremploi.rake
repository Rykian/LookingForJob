namespace :cadremploi do
  desc "Log in to Cadremploi interactively via Playwright and save session to data/cadremploi_session.json"
  task login: :environment do
    require "playwright"

    puts "Opening browser for Cadremploi session setup."
    puts "Complete any Cloudflare challenge and sign in if needed."
    puts "After the search or home page is usable, return here and press Enter to save the session."

    include Sourcing::PlaywrightSupport

    Playwright.create(playwright_cli_executable_path:) do |playwright|
      browser = playwright.chromium.launch(headless: false)
      context = browser.new_context(**default_context_options(locale: "fr-FR"))
      page = context.new_page
      page.goto("https://www.cadremploi.fr/emploi/liste_offres?motsCles=developpeur", waitUntil: "domcontentloaded")

      STDIN.gets

      storage_state = context.storage_state
      Sourcing::Providers::Cadremploi::SessionManager.save(storage_state)

      puts "Session saved to #{Sourcing::Providers::Cadremploi::SessionManager.path}"
      context.close
      browser.close
    end
  end
end
