require "rails_helper"

RSpec.describe Sourcing::PlaywrightSupport do
  subject(:host) { host_class.new }

  let(:host_class) do
    Class.new do
      include Sourcing::PlaywrightSupport

      # Expose the private builder for testing.
      def context_options(**kwargs)
        default_context_options(**kwargs)
      end
    end
  end

  let(:cookies) { [{ "name" => "cf_clearance", "value" => "abc" }] }

  describe "#default_context_options user-agent replay" do
    it "replays the session's userAgent when present" do
      session = { "cookies" => cookies, "origins" => [], "userAgent" => "Mozilla/5.0 Chrome/149.0.0.0" }

      options = host.context_options(locale: "fr-FR", storage_state: session)

      expect(options[:userAgent]).to eq("Mozilla/5.0 Chrome/149.0.0.0")
    end

    it "falls back to DEFAULT_USER_AGENT when the session lacks a userAgent" do
      session = { "cookies" => cookies, "origins" => [] }

      options = host.context_options(locale: "fr-FR", storage_state: session)

      expect(options[:userAgent]).to eq(described_class::DEFAULT_USER_AGENT)
    end

    it "falls back to DEFAULT_USER_AGENT when no session is given" do
      options = host.context_options(locale: "fr-FR")

      expect(options[:userAgent]).to eq(described_class::DEFAULT_USER_AGENT)
    end

    it "strips the userAgent sidecar key from the Playwright storageState" do
      session = { "cookies" => cookies, "origins" => [], "userAgent" => "Mozilla/5.0 Chrome/149.0.0.0" }

      options = host.context_options(locale: "fr-FR", storage_state: session)

      expect(options[:storageState]).to eq("cookies" => cookies, "origins" => [])
    end
  end
end
