namespace :cadremploi do
  desc "Log in to Cadremploi interactively via Playwright and save session to data/cadremploi_session.json"
  task login: :environment do
    require "playwright"

    puts "Opening browser for Cadremploi session setup."
    puts "Complete any Cloudflare challenge and sign in if needed."
    puts "After the search or home page is usable, return here and press Enter to save the session."

    include Sourcing::Providers::SessionLoginSupport

    Playwright.create(playwright_cli_executable_path:) do |playwright|
      browser = playwright.chromium.launch(headless: false)
      existing_state = load_existing_state(
        session_manager: Sourcing::Providers::Cadremploi::SessionManager,
        not_found_error_class: Sourcing::Providers::Cadremploi::SessionNotFoundError
      )

      context_options = if existing_state
        default_context_options(locale: "fr-FR", storage_state: existing_state)
      else
        default_context_options(locale: "fr-FR")
      end

      context = browser.new_context(**context_options)
      page = context.new_page
      bootstrap_url = Sourcing::Providers::Cadremploi::SessionValidator::VALIDATION_URL
      page.goto(bootstrap_url, waitUntil: "domcontentloaded")

      STDIN.gets

      storage_state = context.storage_state
      Sourcing::Providers::Cadremploi::SessionManager.save(storage_state)
      loaded_state = Sourcing::Providers::Cadremploi::SessionManager.load

      validator = Sourcing::Providers::Cadremploi::SessionValidator.new(
        storage_state: loaded_state,
        validation_runner: build_validation_runner(
          browser: browser,
          locale: "fr-FR",
          validation_url: Sourcing::Providers::Cadremploi::SessionValidator::VALIDATION_URL
        )
      )
      validator.validate!

      puts "Session saved and validated at #{Sourcing::Providers::Cadremploi::SessionManager.path}"
      context.close
      browser.close
    end
  rescue Sourcing::Providers::Cadremploi::SessionNotFoundError,
         Sourcing::Providers::Cadremploi::SessionValidationError => e
    Sourcing::Providers::Cadremploi::SessionManager.clear
    raise e.class, e.message
  end
end
