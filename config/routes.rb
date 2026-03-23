Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  get "up" => "rails/health#show", as: :rails_health_check

  # SPA catch-all — must be last
  root "spa#index"
  get "*path", to: "spa#index",
               constraints: ->(req) { !req.path.start_with?("/up") },
               format: false
end
