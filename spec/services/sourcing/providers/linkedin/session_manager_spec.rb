require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::SessionManager do
  let(:session_path) { described_class::SESSION_PATH }
  let(:valid_state) { { "cookies" => [], "origins" => [] } }

  after { described_class.clear }

  describe ".exists?" do
    it "returns false when session file is absent" do
      FileUtils.rm_f(session_path)
      expect(described_class.exists?).to be(false)
    end

    it "returns true when session file is present" do
      described_class.save(valid_state)
      expect(described_class.exists?).to be(true)
    end
  end

  describe ".save and .load" do
    it "round-trips the storage state through the file system" do
      described_class.save(valid_state)
      expect(described_class.load).to eq(valid_state)
    end
  end

  describe ".load" do
    it "raises SessionNotFoundError when file is missing" do
      FileUtils.rm_f(session_path)
      expect { described_class.load }.to raise_error(
        Sourcing::Providers::Linkedin::SessionNotFoundError,
        /linkedin:login/
      )
    end

    it "raises SessionNotFoundError when file is corrupt JSON" do
      File.write(session_path, "not valid json{{{")
      expect { described_class.load }.to raise_error(
        Sourcing::Providers::Linkedin::SessionNotFoundError,
        /corrupt/
      )
    end
  end

  describe ".clear" do
    it "removes the session file" do
      described_class.save(valid_state)
      described_class.clear
      expect(described_class.exists?).to be(false)
    end

    it "does nothing when file is already absent" do
      FileUtils.rm_f(session_path)
      expect { described_class.clear }.not_to raise_error
    end
  end
end
