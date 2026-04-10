module Sourcing
  module Providers
    module SessionLoginSupport
      include Sourcing::PlaywrightSupport

      private

      def load_existing_state(session_manager:, not_found_error_class:)
        return nil unless session_manager.exists?

        session_state = session_manager.load
        session_path = session_manager.respond_to?(:path) ? session_manager.path : session_manager::SESSION_PATH
        puts "Loaded existing session from #{session_path}"
        session_state
      rescue not_found_error_class => e
        puts "Existing session is unusable: #{e.message}. Continuing with fresh login."
        session_manager.clear
        nil
      end

      def build_validation_runner(browser:, locale:, validation_url:)
        lambda do |state, &block|
          validation_context = browser.new_context(**default_context_options(locale: locale, storage_state: state))
          validation_page = validation_context.new_page
          validation_page.goto(validation_url, waitUntil: "domcontentloaded")
          block.call(validation_page)
        ensure
          validation_page&.close rescue nil
          validation_context&.close rescue nil
        end
      end
    end
  end
end
