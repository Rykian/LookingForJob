require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::DiscoveryStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  # TODO: Add integration tests for crawling WTTJ listings
end
