require "rails_helper"

RSpec.describe Sourcing::Providers::Apec::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) { "<html><body><h1>Developpeur Ruby F/H</h1><apec-offre-metadata></apec-offre-metadata></body></html>" }

    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "returns HTML from fetcher" do
      result = step.call(url: "https://www.apec.fr/candidat/recherche-emploi.html/emploi/detail-offre/178367863W")
      expect(result).to eq(stub_html)
    end
  end
end
