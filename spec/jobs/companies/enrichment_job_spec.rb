require "rails_helper"

RSpec.describe Companies::EnrichmentJob, type: :job do
  let(:service) { instance_double(Companies::EnrichmentService, call: nil) }

  before do
    allow(Companies::EnrichmentService).to receive(:new).and_return(service)
  end

  it "enriches the company" do
    company = create(:company)

    described_class.perform_now(company.id)

    expect(service).to have_received(:call).with(company)
  end

  it "is a no-op when already enriched at the current version" do
    company = create(:company, enriched_at: Time.current,
                               enrichment_version: Companies::EnrichmentService::VERSION)

    described_class.perform_now(company.id)

    expect(service).not_to have_received(:call)
  end

  it "re-enriches outdated versions" do
    company = create(:company, enriched_at: Time.current, enrichment_version: 0)

    described_class.perform_now(company.id)

    expect(service).to have_received(:call).with(company)
  end

  it "re-enriches when forced" do
    company = create(:company, enriched_at: Time.current,
                               enrichment_version: Companies::EnrichmentService::VERSION)

    described_class.perform_now(company.id, force: true)

    expect(service).to have_received(:call).with(company)
  end

  it "ignores missing companies" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
