module Sourcing
  class LlmConfig
    DEFAULT_PROVIDER = :openai
    DEFAULT_MODEL = "gpt-5-nano"
    DEFAULT_COMPANY_MODEL = "gpt-5-mini"
    DEFAULT_REQUEST_TIMEOUT = 120
    DEFAULT_MAX_RETRIES = 2

    attr_reader :provider, :model, :company_model, :api_key, :request_timeout, :max_retries

    def self.from_env(env: ENV)
      api_key = env["LLM_API_KEY"] || env["OPENAI_API_KEY"]
      raise KeyError, "Missing OPENAI_API_KEY (or LLM_API_KEY)" if api_key.nil? || api_key.empty?

      provider = (env["LLM_PROVIDER"] || DEFAULT_PROVIDER).to_sym
      model = env["LLM_MODEL"] || env["OPENAI_MODEL"] || DEFAULT_MODEL
      company_model = env["LLM_COMPANY_MODEL"] || DEFAULT_COMPANY_MODEL
      request_timeout = Integer(env.fetch("LLM_REQUEST_TIMEOUT_SECONDS", DEFAULT_REQUEST_TIMEOUT.to_s), 10)
      max_retries = Integer(env.fetch("LLM_MAX_RETRIES", DEFAULT_MAX_RETRIES.to_s), 10)

      new(
        provider: provider,
        model: model,
        company_model: company_model,
        api_key: api_key,
        request_timeout: request_timeout,
        max_retries: max_retries
      )
    end

    def initialize(provider:, model:, api_key:, request_timeout:, max_retries:, company_model: DEFAULT_COMPANY_MODEL)
      @provider = provider.to_sym
      @model = model
      @company_model = company_model
      @api_key = api_key
      @request_timeout = request_timeout
      @max_retries = max_retries
    end

    def configure!(ruby_llm: RubyLLM)
      ruby_llm.configure do |config|
        config.request_timeout = request_timeout
        config.max_retries = max_retries

        case provider
        when :openai
          config.openai_api_key = api_key
        else
          raise ArgumentError, "Unsupported LLM provider: #{provider}"
        end
      end
    end
  end
end
