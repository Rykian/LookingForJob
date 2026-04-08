require "rails_helper"

RSpec.describe Sourcing::Providers::Cadremploi::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) { "<html><body><h1>Développeur Ruby H/F</h1></body></html>" }
    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "calls the fetcher with the provided URL" do
      result = step.call(url: "https://www.cadremploi.fr/emploi/detail_offre?offreId=123")
      expect(result).to eq(stub_html)
    end
  end
end
