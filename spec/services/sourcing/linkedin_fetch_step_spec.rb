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

      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:query_selector).with(described_class::DESCRIPTION_EXPAND_SELECTORS.first).and_return(button)
      allow(button).to receive(:click)
      allow(page_obj).to receive(:wait_for_timeout)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: true, strategy: described_class::DESCRIPTION_EXPAND_SELECTORS.first)
      expect(button).to have_received(:click)
      expect(page_obj).to have_received(:wait_for_timeout).with(400)
    end

    it "falls back to text-based expansion when selectors miss" do
      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:evaluate).and_return(true)
      allow(page_obj).to receive(:wait_for_timeout)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: true, strategy: "text_fallback")
      expect(page_obj).to have_received(:evaluate)
      expect(page_obj).to have_received(:wait_for_timeout).with(400)
    end

    it "returns none when no expansion control is found" do
      allow(page_obj).to receive(:query_selector).and_return(nil)
      allow(page_obj).to receive(:evaluate).and_return(false)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: false, strategy: "none")
    end

    it "returns false when expansion raises" do
      allow(page_obj).to receive(:query_selector).and_raise(StandardError, "boom")
      allow(Rails.logger).to receive(:warn)

      result = step.send(:expand_job_description, page_obj)

      expect(result).to eq(expanded: false, strategy: "error")
      expect(Rails.logger).to have_received(:warn).with(/Could not expand description/)
    end
  end
end
