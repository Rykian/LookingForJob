require "rails_helper"

RSpec.describe Sourcing::CompanyStep do
  let(:llm_payload) do
    {
      "posted_by_recruiter" => false,
      "final_client_guesses" => [],
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

  subject(:step) { described_class.new(llm_config: llm_config, generator: stub_generator) }

  def build_offer(company_name: "Acme", title: "Backend Engineer")
    create(:job_offer, company_name: company_name, title: title,
                       description_html: "<p>Join our team</p>")
  end

  it "returns an empty result without calling the LLM when company name is blank" do
    expect(stub_generator).not_to receive(:call)

    result = step.call(offer: build_offer(company_name: nil))

    expect(result.company_id).to be_nil
    expect(result.posted_by_recruiter).to be_nil
    expect(result.final_client_guesses).to eq([])
    expect(result.final_company_id).to be_nil
  end

  it "links the posting company and records a final-client vote for non-recruiter offers" do
    result = step.call(offer: build_offer)

    company = Company.find(result.company_id)
    expect(company.name).to eq("Acme")
    expect(company.posts_as_final_client).to be(true)
    expect(company.posts_as_recruiter).to be(false)
    expect(result.posted_by_recruiter).to be(false)
    expect(result.final_company_id).to be_nil
  end

  context "when the offer is posted by a recruiter with a confident guess" do
    let(:llm_payload) do
      {
        "posted_by_recruiter" => true,
        "final_client_guesses" => [
          { "name" => "Globex", "confidence" => 0.9, "reasons" => "named in description" },
          { "name" => "Initech", "confidence" => 0.3, "reasons" => "sector hint" },
        ],
      }
    end

    it "auto-links the best guess and records votes" do
      result = step.call(offer: build_offer)

      expect(result.posted_by_recruiter).to be(true)
      expect(result.final_client_guesses.map { |g| g["name"] }).to eq(%w[Globex Initech])
      expect(result.final_client_guesses.first["reasons"]).to eq("named in description")

      final_company = Company.find(result.final_company_id)
      expect(final_company.name).to eq("Globex")
      expect(final_company.posts_as_final_client).to be(true)

      posting_company = Company.find(result.company_id)
      expect(posting_company.posts_as_recruiter).to be(true)
      expect(posting_company.posts_as_final_client).to be(false)
    end
  end

  context "when the best guess is below the confidence threshold" do
    let(:llm_payload) do
      {
        "posted_by_recruiter" => true,
        "final_client_guesses" => [
          { "name" => "Globex", "confidence" => 0.5, "reasons" => "weak hint" },
        ],
      }
    end

    it "stores the guesses without linking a final company" do
      result = step.call(offer: build_offer)

      expect(result.final_client_guesses.size).to eq(1)
      expect(result.final_company_id).to be_nil
      expect(Company.find_by(name: "Globex")).to be_nil
    end
  end

  context "when the best guess resolves to the posting company itself" do
    let(:llm_payload) do
      {
        "posted_by_recruiter" => true,
        "final_client_guesses" => [
          { "name" => "Acme SAS", "confidence" => 0.95, "reasons" => "self reference" },
        ],
      }
    end

    it "never self-links" do
      result = step.call(offer: build_offer)

      expect(result.final_company_id).to be_nil
    end
  end

  context "when guesses arrive unsorted or malformed" do
    let(:llm_payload) do
      {
        "posted_by_recruiter" => true,
        "final_client_guesses" => [
          { "name" => "Low", "confidence" => 0.2, "reasons" => "" },
          { "name" => "High", "confidence" => 0.8, "reasons" => "strong" },
          { "name" => "", "confidence" => 0.99, "reasons" => "blank name" },
          { "name" => "NoConfidence", "confidence" => nil, "reasons" => "x" },
        ],
      }
    end

    it "sorts by confidence and drops invalid entries" do
      result = step.call(offer: build_offer)

      expect(result.final_client_guesses.map { |g| g["name"] }).to eq(%w[High Low])
      expect(Company.find(result.final_company_id).name).to eq("High")
    end
  end

  context "when the enrich step already classified the offer as direct employer" do
    it "skips the LLM call and links the company with a final-client vote" do
      expect(stub_generator).not_to receive(:call)

      offer = create(:job_offer, company_name: "Acme", posted_by_recruiter: false)
      result = step.call(offer: offer)

      company = Company.find(result.company_id)
      expect(company.name).to eq("Acme")
      expect(company.posts_as_final_client).to be(true)
      expect(result.posted_by_recruiter).to be(false)
      expect(result.final_client_guesses).to eq([])
      expect(result.final_company_id).to be_nil
    end
  end

  context "when the enrich step already classified the offer as recruiter-posted" do
    let(:llm_payload) do
      {
        "posted_by_recruiter" => false,
        "final_client_guesses" => [
          { "name" => "Globex", "confidence" => 0.9, "reasons" => "named in description" },
        ],
      }
    end

    it "calls the LLM for guesses and keeps the enrich-time flag over the LLM's" do
      offer = create(:job_offer, company_name: "Acme", posted_by_recruiter: true,
                                 title: "Backend Engineer", description_html: "<p>Join our client</p>")
      result = step.call(offer: offer)

      expect(result.posted_by_recruiter).to be(true)
      expect(Company.find(result.final_company_id).name).to eq("Globex")
    end
  end

  it "never unsets sticky company votes" do
    company = Company.find_or_create_by_name!("Acme")
    company.update!(posts_as_recruiter: true)

    step.call(offer: build_offer)

    expect(company.reload.posts_as_recruiter).to be(true)
    expect(company.posts_as_final_client).to be(true)
  end
end
