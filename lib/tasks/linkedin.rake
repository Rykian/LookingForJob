namespace :linkedin do
  desc "Log in to LinkedIn interactively via Playwright and save session to data/linkedin_session.json"
  task login: :environment do
    require "playwright"

    puts "Opening browser — log in to LinkedIn, then wait for the feed to load."
    puts "The session will be saved automatically. Timeout: 5 minutes."
    include Sourcing::Providers::SessionLoginSupport

    Playwright.create(playwright_cli_executable_path:) do |playwright|
      browser = playwright.chromium.launch(headless: false)
      existing_state = load_existing_state(
        session_manager: Sourcing::Providers::Linkedin::SessionManager,
        not_found_error_class: Sourcing::Providers::Linkedin::SessionNotFoundError
      )

      context_options = if existing_state
        default_context_options(locale: "en-US", storage_state: existing_state)
      else
        default_context_options(locale: "en-US")
      end

      context = browser.new_context(**context_options)
      page = context.new_page
      bootstrap_url = existing_state ? Sourcing::Providers::Linkedin::SessionValidator::VALIDATION_URL : "https://www.linkedin.com/login"
      page.goto(bootstrap_url, waitUntil: "domcontentloaded")

      page.wait_for_url("https://www.linkedin.com/feed/**", timeout: 300_000)
      page.wait_for_timeout(1_000)

      storage_state = context.storage_state
      Sourcing::Providers::Linkedin::SessionManager.save(storage_state)
      loaded_state = Sourcing::Providers::Linkedin::SessionManager.load

      validator = Sourcing::Providers::Linkedin::SessionValidator.new(
        storage_state: loaded_state,
        validation_runner: build_validation_runner(
          browser: browser,
          locale: "en-US",
          validation_url: Sourcing::Providers::Linkedin::SessionValidator::VALIDATION_URL
        )
      )
      validator.validate!

      puts "Session saved and validated at #{Sourcing::Providers::Linkedin::SessionManager::SESSION_PATH}"
      context.close
      browser.close
    end
  rescue Sourcing::Providers::Linkedin::SessionNotFoundError,
         Sourcing::Providers::Linkedin::SessionValidationError => e
    Sourcing::Providers::Linkedin::SessionManager.clear
    raise e.class, e.message
  end
end
