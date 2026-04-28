require "sidekiq/web"

if Rails.env.production?
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    expected_username = ENV.fetch("SIDEKIQ_WEB_USERNAME")
    expected_password = ENV.fetch("SIDEKIQ_WEB_PASSWORD")

    username_match = ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username.to_s),
      ::Digest::SHA256.hexdigest(expected_username)
    )
    password_match = ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(password.to_s),
      ::Digest::SHA256.hexdigest(expected_password)
    )

    username_match & password_match
  end
end

Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  mount ActionCable.server => "/cable"
  get "up" => "rails/health#show", as: :rails_health_check
  mount Sidekiq::Web => "/sidekiq"

  # SPA catch-all — must be last
  root "spa#index"
  get "*path", to: "spa#index",
               constraints: ->(req) { !req.path.start_with?("/up") },
               format: false
end
