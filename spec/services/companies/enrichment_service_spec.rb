require "rails_helper"

RSpec.describe Companies::EnrichmentService do
  let(:llm_payload) do
    {
      "known" => true,
      "official_name" => nil,
      "description" => "Acme builds widgets.",
      "website" => "acme.example",
      "is_recruiter" => false,
      "is_final_client" => true,
    }
  end

  let(:stub_generator) do
    payload = llm_payload
    Class.new {
      define_method(:call) { |**| payload }
    }.new
  end

  let(:llm_config) do
    instance_double(Sourcing::LlmConfig, company_model: "gpt-5-mini", provider: :openai)
  end

  subject(:service) { described_class.new(llm_config: llm_config, generator: stub_generator) }

  let!(:company) { Company.find_or_create_by_name!("Acme") }

  it "persists description, normalized website, flags and enrichment markers" do
    service.call(company)

    company.reload
    expect(company.description).to eq("Acme builds widgets.")
    expect(company.website).to eq("https://acme.example")
    expect(company.posts_as_final_client).to be(true)
    expect(company.posts_as_recruiter).to be(false)
    expect(company.enriched_at).to be_present
    expect(company.enrichment_version).to eq(described_class::VERSION)
  end

  context "when the company is unknown to the model" do
    let(:llm_payload) do
      {
        "known" => false,
        "official_name" => "Hallucinated Name",
        "description" => "Hallucinated description",
        "website" => "hallucinated.example",
        "is_recruiter" => false,
        "is_final_client" => false,
      }
    end

    it "still marks enrichment but persists no profile data" do
      service.call(company)

      company.reload
      expect(company.description).to be_nil
      expect(company.website).to be_nil
      expect(company.name).to eq("Acme")
      expect(company.enriched_at).to be_present
    end
  end

  context "with a confident official name" do
    let(:llm_payload) do
      super().merge("official_name" => "Acme Corporation")
    end

    it "renames the company and keeps an alias for the new name" do
      service.call(company)

      company.reload
      expect(company.name).to eq("Acme Corporation")
      expect(company.aliases.pluck(:normalized_name)).to contain_exactly("acme", "acme corporation")
    end

    it "skips the rename when the name belongs to another company" do
      Company.find_or_create_by_name!("Acme Corporation")

      service.call(company)

      expect(company.reload.name).to eq("Acme")
    end
  end

  it "never unsets sticky flags" do
    company.update!(posts_as_recruiter: true)

    service.call(company)

    expect(company.reload.posts_as_recruiter).to be(true)
  end
end
