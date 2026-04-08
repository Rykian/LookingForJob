require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::SessionValidator do
  let(:storage_state) do
    {
      "cookies" => [
        { "name" => "li_at", "value" => "token" },
      ],
      "origins" => [],
    }
  end

  let(:page_obj) do
    instance_double(
      "Playwright::Page",
      url: "https://www.linkedin.com/feed/",
      title: "Feed | LinkedIn"
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
        "loginForm" => false,
        "challengeContainer" => false,
        "hasFeedContainer" => true,
      }
    )
  end

  it "accepts an authenticated session on a non-blocked page" do
    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect(validator.validate!).to be(true)
  end

  it "does not treat feed page as blocked when generic challenge wording appears in title" do
    allow(page_obj).to receive(:url).and_return("https://www.linkedin.com/feed/")
    allow(page_obj).to receive(:title).and_return("My weekly challenge updates | LinkedIn")
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "loginForm" => false,
        "challengeContainer" => false,
        "hasFeedContainer" => true,
      }
    )

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect(validator.validate!).to be(true)
  end

  it "rejects storage state without the LinkedIn auth cookie" do
    validator = described_class.new(
      storage_state: { "cookies" => [], "origins" => [] },
      validation_runner: validation_runner
    )

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Linkedin::SessionValidationError,
      /missing li_at auth cookie/
    )
  end

  it "rejects a blocked or login page during validation" do
    allow(page_obj).to receive(:url).and_return("https://www.linkedin.com/login")
    allow(page_obj).to receive(:title).and_return("Sign in to LinkedIn")
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "loginForm" => true,
        "challengeContainer" => false,
        "hasFeedContainer" => false,
      }
    )

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Linkedin::SessionValidationError,
      /login_or_challenge_page/
    )
  end

  it "rejects a challenge container even on feed url" do
    allow(page_obj).to receive(:url).and_return("https://www.linkedin.com/feed/")
    allow(page_obj).to receive(:title).and_return("Fil d'actualite | LinkedIn")
    allow(page_obj).to receive(:evaluate).and_return(
      {
        "loginForm" => false,
        "challengeContainer" => true,
        "hasFeedContainer" => true,
      }
    )

    validator = described_class.new(storage_state: storage_state, validation_runner: validation_runner)

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Linkedin::SessionValidationError,
      /login_or_challenge_page/
    )
  end

  it "wraps unexpected validation runner errors" do
    validator = described_class.new(
      storage_state: storage_state,
      validation_runner: ->(_state, &_block) { raise "boom" }
    )

    expect { validator.validate! }.to raise_error(
      Sourcing::Providers::Linkedin::SessionValidationError,
      /boom/
    )
  end
end
