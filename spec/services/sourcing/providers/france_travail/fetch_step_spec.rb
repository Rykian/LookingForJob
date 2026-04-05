require "rails_helper"

RSpec.describe Sourcing::Providers::FranceTravail::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "#call with stub fetcher" do
    let(:stub_html) { "<html><body><div itemprop='description'><p>Job desc</p></div></body></html>" }
    let(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "delegates to the injected fetcher and returns HTML" do
      result = step.call(url: "https://candidat.francetravail.fr/offres/recherche/detail/206JYDL")
      expect(result).to eq(stub_html)
    end
  end
end
