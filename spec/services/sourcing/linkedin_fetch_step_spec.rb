require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::FetchStep do
  it "returns fetched html from injected fetcher" do
    fetcher = ->(input) { "<html>#{input.fetch(:url)}</html>" }

    html = described_class.new(fetcher: fetcher).call(
      source: "linkedin",
      url: "https://example.com/jobs/1",
      url_hash: "hash"
    )

    expect(html).to include("https://example.com/jobs/1")
  end

  describe "#expand_job_description" do
    let(:step) { described_class.new(fetcher: ->(_input) { "<html></html>" }) }
    let(:page_obj) { instance_double("Playwright::Page") }

    it "clicks known LinkedIn description expand button when present" do
      button = instance_double("Playwright::ElementHandle")

      allow(page_obj).to receive(:evaluate).and_return(false)
      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:query_selector).with(described_class::DESCRIPTION_EXPAND_SELECTORS.first).and_return(button)
      allow(button).to receive(:click)
      allow(page_obj).to receive(:wait_for_timeout)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: true, strategy: described_class::DESCRIPTION_EXPAND_SELECTORS.first)
      expect(button).to have_received(:click).with(timeout: 1_200)
      expect(page_obj).to have_received(:wait_for_timeout).with(400)
    end

    it "falls back to text-based expansion when selectors miss" do
      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:evaluate).and_return(false, true)
      allow(page_obj).to receive(:wait_for_timeout)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: true, strategy: "text_fallback")
      expect(page_obj).to have_received(:evaluate).twice
      expect(page_obj).to have_received(:wait_for_timeout).with(400)
    end

    it "returns none when no expansion control is found" do
      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:evaluate).and_return(false, false)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: false, strategy: "none")
    end

    it "short-circuits when a blocking overlay is visible" do
      allow(page_obj).to receive(:evaluate).and_return(true)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: false, strategy: "blocked_overlay")
      expect(page_obj).to have_received(:evaluate).once
    end

    it "returns false when expansion raises" do
      allow(page_obj).to receive(:evaluate).and_return(false)
      allow(page_obj).to receive(:query_selector).and_raise(StandardError, "boom")
      allow(Rails.logger).to receive(:warn)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: false, strategy: "error")
      expect(Rails.logger).to have_received(:warn).with(/Could not expand description/)
    end
  end

  describe "#ensure_valid_content!" do
    let(:step) { described_class.new(fetcher: ->(_input) { "<html></html>" }) }

    it "raises for shell html" do
      diagnostics = {
        marker_found: false,
        body_text_length: 0,
        blocked_page: false,
        current_url: "https://www.linkedin.com/jobs/view/1",
        title: "",
        html_length: 39,
      }

      expect do
        step.send(
          :ensure_valid_content!,
          url: "https://www.linkedin.com/jobs/view/1",
          html: "<html><head></head><body></body></html>",
          diagnostics: diagnostics
        )
      end.to raise_error(Sourcing::Providers::Linkedin::FetchContentError, /shell_html/)
    end

    it "raises when markers are missing and body text is too short" do
      diagnostics = {
        marker_found: false,
        body_text_length: 20,
        blocked_page: false,
        current_url: "https://www.linkedin.com/jobs/view/1",
        title: "LinkedIn",
        html_length: 120,
      }

      expect do
        step.send(
          :ensure_valid_content!,
          url: "https://www.linkedin.com/jobs/view/1",
          html: "<html><body><div>small payload</div></body></html>",
          diagnostics: diagnostics
        )
      end.to raise_error(Sourcing::Providers::Linkedin::FetchContentError, /missing_job_markers/)
    end

    it "accepts html when at least one marker is present" do
      diagnostics = {
        marker_found: true,
        body_text_length: 50,
        blocked_page: false,
        current_url: "https://www.linkedin.com/jobs/view/1",
        title: "Job",
        html_length: 500,
      }

      expect do
        step.send(
          :ensure_valid_content!,
          url: "https://www.linkedin.com/jobs/view/1",
          html: "<html><body><h1 class='jobs-unified-top-card__job-title'>Role</h1></body></html>",
          diagnostics: diagnostics
        )
      end.not_to raise_error
    end
  end
end
