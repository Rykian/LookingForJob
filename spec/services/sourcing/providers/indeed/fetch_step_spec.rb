require "rails_helper"

RSpec.describe Sourcing::Providers::Indeed::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  describe "with stub fetcher" do
    let(:stub_html) do
      <<~HTML
        <html><body>
          <h1 data-testid="jobsearch-JobInfoHeader-title">Senior Backend Engineer</h1>
          <div id="jobDescriptionText"><p>Rejoignez notre equipe.</p></div>
          <script type="application/ld+json">{"@type":"JobPosting","title":"Senior Backend Engineer"}</script>
        </body></html>
      HTML
    end

    subject(:step) { described_class.new(fetcher: ->(**) { stub_html }) }

    it "returns HTML from fetcher" do
      result = step.call(url: "https://fr.indeed.com/viewjob?jk=abc123")
      expect(result).to eq(stub_html)
    end
  end
end
