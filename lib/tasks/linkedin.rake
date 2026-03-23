namespace :linkedin do
  desc "Log in to LinkedIn interactively via Playwright and save session to data/linkedin_session.json"
  task login: :environment do
    require "playwright"

    puts "Opening browser — log in to LinkedIn, then wait for the feed to load."
    puts "The session will be saved automatically. Timeout: 5 minutes."

    Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
      browser = playwright.chromium.launch(headless: false)
      context = browser.new_context
      page = context.new_page
      page.goto("https://www.linkedin.com/login", waitUntil: "domcontentloaded")

      page.wait_for_url("https://www.linkedin.com/feed/**", timeout: 300_000)

      storage_state = context.storage_state
      Sourcing::Providers::Linkedin::SessionManager.save(storage_state)

      puts "Session saved to #{Sourcing::Providers::Linkedin::SessionManager::SESSION_PATH}"
      context.close
      browser.close
    end
  end
end
