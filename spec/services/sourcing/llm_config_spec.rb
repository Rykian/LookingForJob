require "rails_helper"

RSpec.describe Sourcing::LlmConfig do
  describe ".from_env" do
    it "loads provider, model and retries from env" do
      env = {
        "LLM_PROVIDER" => "openai",
        "LLM_MODEL" => "gpt-4.1",
        "LLM_API_KEY" => "test-key",
        "LLM_REQUEST_TIMEOUT_SECONDS" => "45",
        "LLM_MAX_RETRIES" => "5",
      }

      config = described_class.from_env(env: env)

      expect(config.provider).to eq(:openai)
      expect(config.model).to eq("gpt-4.1")
      expect(config.api_key).to eq("test-key")
      expect(config.request_timeout).to eq(45)
      expect(config.max_retries).to eq(5)
    end

    it "falls back to openai env vars when generic vars are missing" do
      env = {
        "OPENAI_MODEL" => "gpt-4.1-mini",
        "OPENAI_API_KEY" => "openai-key",
      }

      config = described_class.from_env(env: env)

      expect(config.provider).to eq(:openai)
      expect(config.model).to eq("gpt-4.1-mini")
      expect(config.api_key).to eq("openai-key")
      expect(config.request_timeout).to eq(120)
      expect(config.max_retries).to eq(2)
    end
  end

  describe "#configure!" do
    it "applies timeout, retries and provider credentials" do
      config = described_class.new(
        provider: :openai,
        model: "gpt-4.1-mini",
        api_key: "k",
        request_timeout: 30,
        max_retries: 4,
      )

      fake_ruby_llm = Class.new do
        attr_reader :config

        def configure
          @config = Struct.new(:request_timeout, :max_retries, :openai_api_key).new
          yield @config
        end
      end.new

      config.configure!(ruby_llm: fake_ruby_llm)

      expect(fake_ruby_llm.config.request_timeout).to eq(30)
      expect(fake_ruby_llm.config.max_retries).to eq(4)
      expect(fake_ruby_llm.config.openai_api_key).to eq("k")
    end
  end
end
