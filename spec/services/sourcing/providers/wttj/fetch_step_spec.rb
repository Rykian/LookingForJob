require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  # TODO: Add integration tests for fetching WTTJ job details
end

RSpec.describe "Sourcing::Providers::Wttj::FetchStep integration", :integration do
  let(:real_url) { "https://www.welcometothejungle.com/fr/companies/edf/jobs/alternance-bac-3-appui-communication-graphisme-audiovisuel-f-h_paris" } # Replace with a current, public job URL if needed
  let(:step) { Sourcing::Providers::Wttj::FetchStep.new }

  it "fetches real WTTJ job HTML" do
    html = step.call(url: real_url)
    expect(html).to include("<html")
    expect(html).to match(/(description|Descriptif du poste)/i)
  end
end
