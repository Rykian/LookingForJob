module Sourcing
  module Providers
    module Linkedin
      class FetchStep < Sourcing::FetchStep
        DESCRIPTION_EXPAND_SELECTORS = [
          ".show-more-less-html__button--more",
          ".jobs-description__footer-button",
          "button[aria-label*='description']"
        ].freeze

        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          require "playwright"

          html = nil

          session = Sourcing::Providers::Linkedin::SessionManager.load

          Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
            browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(storageState: session)
            page_obj = context.new_page
            page_obj.goto(url, waitUntil: "domcontentloaded")
            page_obj.wait_for_timeout(1000)
            expansion = expand_job_description(page_obj)
            Rails.logger.info(
              "[Linkedin::FetchStep] Description expansion strategy=#{expansion[:strategy]} expanded=#{expansion[:expanded]} url=#{url}"
            )
            html = page_obj.content
            context.close
            browser.close
          end

          html
        end

        def expand_job_description(page_obj)
          DESCRIPTION_EXPAND_SELECTORS.each do |selector|
            button = page_obj.query_selector(selector)
            next unless button

            button.click
            page_obj.wait_for_timeout(400)
            return { expanded: true, strategy: selector }
          end

          clicked = page_obj.evaluate(<<~JS)
            () => {
              const isVisible = (el) => !!(el && (el.offsetParent || el.getClientRects().length));
              const normalize = (text) => (text || "").trim().toLowerCase().replace(/\s+/g, " ");

              const candidates = Array.from(document.querySelectorAll("button, a")).filter((el) => {
                if (!isVisible(el)) return false;

                const text = normalize(el.textContent || "");
                return /(more|see more|show more|plus|voir plus|afficher plus)/i.test(text);
              });

              const isStrongExpandCandidate = (el) => {
                const text = normalize(el.textContent || "");

                // Prefer concise expander labels and ignore generic links.
                if (/learn more|jobs like this/.test(text)) return false;
                if (/^(…|\.\.\.)?\s*(more|see more|show more|plus|voir plus|afficher plus)$/.test(text)) return true;

                const aria = normalize(el.getAttribute("aria-label") || "");
                return /(see more|show more|voir plus|afficher plus|description)/.test(aria);
              };

              const target =
                candidates.find((el) => el.closest(".jobs-description, .jobs-description__content, .show-more-less-html")) ||
                candidates.find((el) => el.tagName === "BUTTON" && isStrongExpandCandidate(el)) ||
                candidates.find((el) => isStrongExpandCandidate(el)) ||
                candidates[0];

              if (!target) return false;
              target.click();
              return true;
            }
          JS

          if clicked
            page_obj.wait_for_timeout(400)
            return { expanded: true, strategy: "text_fallback" }
          end

          { expanded: false, strategy: "none" }
        rescue StandardError => e
          Rails.logger.warn("[Linkedin::FetchStep] Could not expand description: #{e.class}: #{e.message}")
          { expanded: false, strategy: "error" }
        end
      end
    end
  end
end
