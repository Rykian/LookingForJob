require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::FetchStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::FetchStep" do
    expect(step).to be_a(Sourcing::FetchStep)
  end

  let(:payload) { { "objectID" => "greenhouse+5967999002", "title" => "Backend Engineer" }.to_json }
  let(:url) { "https://www.welovedevs.com/app/jobs?jobId=greenhouse%2B5967999002" }

  def fake_client(object_id: "greenhouse+5967999002", body: payload)
    client = instance_double(Sourcing::Providers::Welovedevs::AlgoliaClient)
    allow(client).to receive(:get_object).with(object_id).and_return(body)
    client
  end

  describe "#fetch_page" do
    it "decodes the jobId from the URL and returns the raw Algolia JSON body" do
      step = described_class.new(client: fake_client)
      expect(step.call(url: url)).to eq(payload)
    end

    it "raises OfferGoneError when the object is missing (404 → nil body)" do
      step = described_class.new(client: fake_client(body: nil))
      expect { step.call(url: url) }.to raise_error(Sourcing::OfferGoneError, /not found/)
    end

    it "retires a legacy /app/job/<slug> URL (no jobId) as a gone offer" do
      step = described_class.new(client: fake_client)
      legacy = "https://www.welovedevs.com/app/job/backend-engineer-wm-datadome"
      expect { step.call(url: legacy) }.to raise_error(Sourcing::OfferGoneError, /legacy URL/)
    end

    it "raises a loud error when the payload is not a job object" do
      step = described_class.new(client: fake_client(body: { "objectID" => "x" }.to_json))
      expect { step.call(url: url) }.to raise_error(StandardError, /not a job payload/)
    end

    it "raises a loud error when the body is not valid JSON" do
      step = described_class.new(client: fake_client(body: "<html>nope</html>"))
      expect { step.call(url: url) }.to raise_error(StandardError, /not valid JSON/)
    end
  end

  describe "with stub fetcher" do
    subject(:step) { described_class.new(fetcher: ->(**) { payload }) }

    it "calls the injected fetcher with the provided URL" do
      expect(step.call(url: url)).to eq(payload)
    end
  end
end
