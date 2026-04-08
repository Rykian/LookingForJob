require "rails_helper"

RSpec.describe Sourcing::Providers::Cadremploi::SessionValidator do
  let(:storage_state) do
    {
      "cookies" => [
        { "name" => "cf_clearance", "value" => "token" },
      ],
      "origins" => [],
    }
  end

  let(:page_obj) do
    instance_double(
      "Playwright::Page",
      url: "https://www.cadremploi.fr/emploi/liste_offres?motsCles=developpeur",
      title: "Offres d'emploi - Cadremploi"
    )
  end

  let(:validation_runner) do
    lambda do |_state, &block|
      block.call(page_obj)
    end
  end

  before do
    allow(page_obj).to receive(:wait_for_timeout)
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "challengeContainer" => false,
        "hasBlockingOverlay" => false,
        "hasJobList" => true,
      }
    )
  end

  it "accepts a valid session on a non-blocked page" do
    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect(validator.validate!).to be(true)
  end

  it "rejects invalid storage-state shape" do
    validator = described_class.new(storage_state: { "cookies" => "wrong" }, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Cadremploi::SessionValidationError,
      /invalid/
    )
  end

  it "rejects blocked url" do
    allow(page_obj).to receive(:url).and_return("https://www.cadremploi.fr/cdn-cgi/challenge-platform/h/b")

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Cadremploi::SessionValidationError,
      /challenge_or_login_page/
    )
  end

  it "rejects challenge markers in page" do
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "challengeContainer" => true,
        "hasBlockingOverlay" => false,
        "hasJobList" => true,
      }
    )

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Cadremploi::SessionValidationError,
      /challenge_or_login_page/
    )
  end

  it "rejects pages without job list markers" do
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "challengeContainer" => false,
        "hasBlockingOverlay" => false,
        "hasJobList" => false,
      }
    )

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Cadremploi::SessionValidationError,
      /challenge_or_login_page/
    )
  end
end