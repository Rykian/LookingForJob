namespace :wttj do
  desc "Harvest a WTTJ session from a running Chrome over CDP (--remote-debugging-port=9222)"
  task login: :environment do
    Sourcing::Providers::CdpSessionHarvester.new(
      session_manager: Sourcing::Providers::Wttj::SessionManager,
      domain_pattern: /(?:^|\.)welcometothejungle\.com$/i,
      target_url: "https://www.welcometothejungle.com/fr/jobs-matches",
      critical_cookies: %w[aws-waf-token wttj-session wttj-token],
    ).call
  end
end
