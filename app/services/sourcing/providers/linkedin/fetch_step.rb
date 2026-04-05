module Sourcing
  module Providers
    module Linkedin
      class FetchContentError < StandardError; end

      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        DESCRIPTION_EXPAND_SELECTORS = [
          ".show-more-less-html__button--more",
          ".jobs-description__footer-button",
          "button[aria-label*='description']",
        ].freeze

        JOB_MARKER_SELECTORS = [
          ".job-details-jobs-unified-top-card__job-title h1",
          ".jobs-unified-top-card__job-title",
          ".jobs-description__content",
          ".show-more-less-html__markup",
          "[data-testid='expandable-text-box']",
        ].freeze

        BLOCKED_PAGE_PATTERN = /(checkpoint|challenge|captcha|authwall|login|sign in|security verification)/i
        MIN_BODY_TEXT_LENGTH = 400

        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          session = Sourcing::Providers::Linkedin::SessionManager.load

          with_playwright_page(url: url, locale: "en-US", storage_state: session) do |page_obj|
            wait_for_job_markers(page_obj)
            expansion = expand_job_description(page_obj)
            html = page_obj.content
            diagnostics = page_diagnostics(page_obj, html: html)
            ensure_valid_content!(url: url, html: html, diagnostics: diagnostics)
            Rails.logger.info(
              "[Linkedin::FetchStep] Description expansion strategy=#{expansion[:strategy]} expanded=#{expansion[:expanded]} markers=#{diagnostics[:marker_found]} body_text_length=#{diagnostics[:body_text_length]} url=#{url}"
            )
            html
          end
        end

        def wait_for_job_markers(page_obj)
          timeout_ms = ENV.fetch("LINKEDIN_FETCH_MARKER_TIMEOUT_MS", "12000").to_i
          found = wait_for_any_selector(
            page_obj: page_obj,
            selectors: JOB_MARKER_SELECTORS,
            timeout_ms: timeout_ms,
            wait_options: { state: "attached" }
          )
          return if found

          # LinkedIn pages are often hydrated after first paint. Try a short fallback pass.
          page_obj.wait_for_timeout(700)
          page_obj.evaluate(<<~JS)
            () => {
              if (document && document.body) {
                window.scrollBy(0, Math.max(400, window.innerHeight * 0.8));
              }
            }
          JS
          page_obj.wait_for_timeout(700)
        end

        def page_diagnostics(page_obj, html:)
          title = page_obj.title.to_s
          current_url = page_obj.url.to_s
          body_text_length = page_obj.evaluate(<<~JS)
            () => {
              const body = document && document.body ? document.body.innerText : "";
              return (body || "").trim().length;
            }
          JS

          {
            title: title,
            current_url: current_url,
            marker_found: marker_found?(page_obj),
            body_text_length: body_text_length.to_i,
            blocked_page: blocked_page?(url: current_url, title: title),
            html_length: html.to_s.length,
          }
        rescue StandardError => e
          Rails.logger.warn("[Linkedin::FetchStep] Could not compute diagnostics for url=#{page_obj.url}: #{e.class}: #{e.message}")
          {
            title: "",
            current_url: page_obj.url.to_s,
            marker_found: false,
            body_text_length: 0,
            blocked_page: false,
            html_length: html.to_s.length,
          }
        end

        def marker_found?(page_obj)
          JOB_MARKER_SELECTORS.any? { |selector| page_obj.query_selector(selector) }
        end

        def blocked_page?(url:, title:)
          payload = "#{url} #{title}".downcase
          payload.match?(BLOCKED_PAGE_PATTERN)
        end

        def ensure_valid_content!(url:, html:, diagnostics:)
          normalized = html.to_s.strip
          raise FetchContentError, "LinkedIn fetch produced empty_html for url=#{url}" if normalized.empty?

          compact_html = normalized.downcase.gsub(/\s+/, "")
          if compact_html == "<html><head></head><body></body></html>" || compact_html == "<html><body></body></html>"
            raise FetchContentError, "LinkedIn fetch produced shell_html for url=#{url}"
          end

          if diagnostics[:blocked_page]
            raise FetchContentError,
                  "LinkedIn fetch reached challenge_or_login_page for url=#{url} current_url=#{diagnostics[:current_url]} title=#{diagnostics[:title].inspect}"
          end

          return if diagnostics[:marker_found]
          return if diagnostics[:body_text_length] >= MIN_BODY_TEXT_LENGTH

          raise FetchContentError,
                "LinkedIn fetch produced missing_job_markers for url=#{url} body_text_length=#{diagnostics[:body_text_length]} html_length=#{diagnostics[:html_length]}"
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
