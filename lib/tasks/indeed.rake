namespace :indeed do
  desc "Harvest an Indeed session from a running Chrome over CDP (--remote-debugging-port=9222)"
  task login: :environment do
    Sourcing::Providers::CdpSessionHarvester.new(
      session_manager: Sourcing::Providers::Indeed::SessionManager,
      domain_pattern: /(?:^|\.)indeed\.com$/i,
      target_url: "https://fr.indeed.com",
      critical_cookies: %w[cf_clearance CTK INDEED_CSRF_TOKEN SOCK SHOE JSESSIONID],
    ).call
  end
end
