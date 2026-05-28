require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end
end

RSpec.describe "Sourcing::Providers::Wttj::FetchStep integration", :integration do
  # Pulled from sitemaps/job-listings.0.xml.gz; replace with a current URL if expired.
  let(:real_url) { "https://www.welcometothejungle.com/fr/companies/nexans/jobs/cable-jointer_oslo" }
  let(:step) { Sourcing::Providers::Wttj::FetchStep.new }

  it "fetches real WTTJ job HTML" do
    html = step.call(url: real_url)
    expect(html).to include("<html")
    expect(html).to match(/(description|Descriptif du poste|JobPosting)/i)
  end
end
