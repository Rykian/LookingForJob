require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::DiscoveryStep do
  subject(:step) { described_class.new(connection: fake_connection) }

  let(:fake_response) { instance_double(Faraday::Response, success?: true, status: 200, body: search_html) }
  let(:fake_connection) { instance_double(Faraday::Connection) }

  let(:search_html) do
    <<~HTML
      <li>
        <div class="base-card" data-entity-urn="urn:li:jobPosting:4374109608">
          <a class="base-card__full-link"
             href="https://fr.linkedin.com/jobs/view/junior-backend-engineer-typescript-at-cozycozy-com-4374109608?position=1"></a>
        </div>
      </li>
      <li>
        <div class="base-card" data-entity-urn="urn:li:jobPosting:4412803359">
          <a class="base-card__full-link"
             href="https://fr.linkedin.com/jobs/view/d%C3%A9veloppeur-backend-java-at-aubay-4412803359?position=4"></a>
        </div>
      </li>
    HTML
  end

  before do
    allow(fake_connection).to receive(:get).and_return(fake_response)
    allow(step).to receive(:throttle!)
  end

  it "inherits from Sourcing::DiscoveryStep" do
    expect(step).to be_a(Sourcing::DiscoveryStep)
  end

  describe "#crawl_page" do
    it "extracts canonical job URLs from the guest search HTML" do
      runtime = step.setup(input: { keyword: "backend" })
      result = step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 1)

      expect(result[:discovered_urls]).to match_array([
        "https://www.linkedin.com/jobs/view/4374109608/",
        "https://www.linkedin.com/jobs/view/4412803359/",
      ])
      expect(result[:has_next_page]).to be true
    end

    it "stops paginating at MAX_PAGES" do
      runtime = step.setup(input: {})
      result = step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: described_class::MAX_PAGES)

      expect(result[:has_next_page]).to be false
    end

    it "stops paginating when a page returns no jobs" do
      empty_response = instance_double(Faraday::Response, success?: true, status: 200, body: "")
      allow(fake_connection).to receive(:get).and_return(empty_response)
      runtime = step.setup(input: {})

      result = step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 1)

      expect(result[:discovered_urls]).to be_empty
      expect(result[:has_next_page]).to be false
    end

    it "raises loudly on non-success HTTP responses" do
      bad_response = instance_double(Faraday::Response, success?: false, status: 429, body: "")
      allow(fake_connection).to receive(:get).and_return(bad_response)
      runtime = step.setup(input: {})

      expect {
        step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 1)
      }.to raise_error(/HTTP 429/)
    end

    it "passes the f_WT work-mode filter when work_mode is set" do
      runtime = step.setup(input: {})
      step.crawl_page(input: { keyword: "backend", work_mode: "remote" }, runtime: runtime, page: 1)

      expect(fake_connection).to have_received(:get).with(/f_WT=2/)
    end

    it "omits the f_WT param when work_mode is nil" do
      runtime = step.setup(input: {})
      step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 1)

      expect(fake_connection).to have_received(:get).with(/\A((?!f_WT).)*\z/)
    end

    it "translates page number to start= offset (page=3 -> start=20)" do
      runtime = step.setup(input: {})
      step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 3)

      expect(fake_connection).to have_received(:get).with(/start=20/)
    end

    it "throttles between pages (skipped on page 1)" do
      runtime = step.setup(input: {})
      step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 1)
      expect(step).not_to have_received(:throttle!)

      step.crawl_page(input: { keyword: "backend" }, runtime: runtime, page: 2)
      expect(step).to have_received(:throttle!).once
    end
  end
end
