require "rails_helper"

RSpec.describe Sourcing::Providers::Hellowork::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) { "<html><body><h1>Developpeur Ruby H/F</h1></body></html>" }
    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "returns HTML from fetcher" do
      result = step.call(url: "https://www.hellowork.com/fr-fr/emplois/77465108.html")
      expect(result).to eq(stub_html)
    end
  end
end
