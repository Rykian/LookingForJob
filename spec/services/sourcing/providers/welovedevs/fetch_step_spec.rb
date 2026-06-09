require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) { "<html><body><h1>Backend Engineer</h1></body></html>" }
    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "calls the fetcher with the provided URL" do
      result = step.call(url: "https://www.welovedevs.com/app/job/backend-engineer-wm-datadome")
      expect(result).to eq(stub_html)
    end
  end

  describe "#fetch_page content validation" do
    # Minimal Playwright page stand-in: `ready` controls whether selectors resolve.
    let(:fake_page_class) do
      Class.new do
        def initialize(html:, ready:)
          @html = html
          @ready = ready
        end

        def query_selector(selector)
          return :node if @ready && ["script[type='application/ld+json']", "h1"].include?(selector)

          nil
        end

        def wait_for_selector(_combined, **)
          raise "timeout" unless @ready

          :ok
        end

        def content
          @html
        end
      end
    end

    let(:url) { "https://www.welovedevs.com/app/job/backend-engineer-wm-datadome" }

    def stub_page(html:, ready:)
      page = fake_page_class.new(html: html, ready: ready)
      allow(step).to receive(:with_playwright_page) { |**_kwargs, &blk| blk.call(page) }
    end

    it "returns the HTML when a JobPosting JSON-LD block is present" do
      html = %(<html><body><h1>Job</h1><script type="application/ld+json">{"@type":"JobPosting"}</script></body></html>)
      stub_page(html: html, ready: true)

      expect(step.call(url: url)).to eq(html)
    end

    it "raises OfferGoneError when nothing loads and no JobPosting is present" do
      stub_page(html: "<html><body><h1>Page introuvable</h1></body></html>", ready: false)

      expect { step.call(url: url) }.to raise_error(Sourcing::OfferGoneError, /removed or unavailable/)
    end

    it "raises a loud error when content loads but no JobPosting is present (selector drift)" do
      stub_page(html: "<html><body><h1>Some non-offer page</h1></body></html>", ready: true)

      expect { step.call(url: url) }.to raise_error(StandardError, /selector drift|without a JobPosting/)
    end
  end
end
