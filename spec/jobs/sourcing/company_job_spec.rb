require "rails_helper"
require_relative "shared_version_checking_examples"

RSpec.describe Sourcing::CompanyJob, type: :job do
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  def build_result(company: nil, posted_by_recruiter: false, guesses: [], final_company: nil)
    Sourcing::CompanyStep::Result.new(
      company_id: company&.id,
      posted_by_recruiter: posted_by_recruiter,
      final_client_guesses: guesses,
      final_company_id: final_company&.id
    )
  end

  it "persists step output and advances the pipeline" do
    allow(Sourcing::Pipeline).to receive(:advance)
    offer = create(:job_offer, company_name: "Acme")
    company = Company.find_or_create_by_name!("Acme")
    allow(Sourcing::CompanyStep).to receive(:call).and_return(
      build_result(
        company: company,
        posted_by_recruiter: true,
        guesses: [{ "name" => "Globex", "confidence" => 0.9, "reasons" => "named" }]
      )
    )

    described_class.perform_now(offer.id)

    offer.reload
    expect(offer.company_id).to eq(company.id)
    expect(offer.posted_by_recruiter).to be(true)
    expect(offer.final_client_guesses.first).to include("name" => "Globex")
    expect(offer.steps_details["company"]).to include("version" => Sourcing::CompanyStep::VERSION)
    expect(Sourcing::Pipeline).to have_received(:advance).with(
      satisfy { |o| o.id == offer.id },
      "company",
      nil,
      force: false
    )
  end

  it "enqueues enrichment for linked companies that were never enriched" do
    allow(Sourcing::Pipeline).to receive(:advance)
    offer = create(:job_offer, company_name: "Acme")
    company = Company.find_or_create_by_name!("Acme")
    final_company = Company.find_or_create_by_name!("Globex")
    final_company.update!(enriched_at: Time.current, enrichment_version: Companies::EnrichmentService::VERSION)
    allow(Sourcing::CompanyStep).to receive(:call).and_return(
      build_result(company: company, final_company: final_company)
    )

    described_class.perform_now(offer.id)

    enrichment_jobs = enqueued_jobs.select { |j| j[:job] == Companies::EnrichmentJob }
    expect(enrichment_jobs.map { |j| j[:args].first }).to eq([company.id])
  end

  it "returns early for duplicate offers without calling the step" do
    allow(Sourcing::Pipeline).to receive(:advance)
    canonical = create(:job_offer)
    offer = create(:job_offer, company_name: "Acme", canonical_offer: canonical)

    expect(Sourcing::CompanyStep).not_to receive(:call)

    described_class.perform_now(offer.id)

    expect(Sourcing::Pipeline).not_to have_received(:advance)
  end

  it "returns early for rejected offers" do
    allow(Sourcing::Pipeline).to receive(:advance)
    offer = create(:job_offer, :rejected, company_name: "Acme")

    expect(Sourcing::CompanyStep).not_to receive(:call)

    described_class.perform_now(offer.id)
  end

  it "marks the step even when the offer has no company name" do
    allow(Sourcing::Pipeline).to receive(:advance)
    offer = create(:job_offer, company_name: nil)
    allow(Sourcing::CompanyStep).to receive(:call).and_return(build_result)

    described_class.perform_now(offer.id)

    expect(offer.reload.steps_details["company"]).to include("version" => Sourcing::CompanyStep::VERSION)
  end

  describe "version checking behavior" do
    let(:step_name) { "company" }
    let(:current_version) { Sourcing::CompanyStep::VERSION }
    let(:extra_offer_attrs) { { company_name: "Acme" } }

    def prepare_offer(offer); end

    def stub_step_not_to_be_called
      expect(Sourcing::CompanyStep).not_to receive(:call)
    end

    def stub_step_to_be_called_once
      company = Company.find_or_create_by_name!("Acme")
      expect(Sourcing::CompanyStep).to receive(:call).once.and_return(
        Sourcing::CompanyStep::Result.new(
          company_id: company.id,
          posted_by_recruiter: false,
          final_client_guesses: [],
          final_company_id: nil
        )
      )
    end

    it_behaves_like "skippable sourcing job with version checking"
  end
end
