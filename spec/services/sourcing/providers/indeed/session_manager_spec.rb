require "rails_helper"

RSpec.describe Sourcing::Providers::Indeed::SessionManager do
  let(:tmp_path) { Rails.root.join("tmp", "indeed_session_spec.json") }
  let(:valid_state) { { "cookies" => [], "origins" => [] } }

  before do
    stub_const("Sourcing::Providers::Indeed::SessionManager::SESSION_PATH", tmp_path)
    FileUtils.rm_f(tmp_path)
  end

  after { FileUtils.rm_f(tmp_path) }

  describe ".save / .load" do
    it "roundtrips valid storage state" do
      described_class.save(valid_state)
      expect(described_class.load).to eq(valid_state)
    end

    it "raises SessionNotFoundError on missing keys" do
      expect { described_class.save({ "cookies" => [] }) }
        .to raise_error(Sourcing::Providers::Indeed::SessionNotFoundError, /origins/)
    end

    it "raises SessionNotFoundError when the file is invalid JSON" do
      File.write(tmp_path, "not json")
      expect { described_class.load }
        .to raise_error(Sourcing::Providers::Indeed::SessionNotFoundError, /invalid JSON/)
    end
  end

  describe ".load_if_exists" do
    it "returns nil when no file is present" do
      expect(described_class.load_if_exists).to be_nil
    end

    it "returns the parsed state when present" do
      described_class.save(valid_state)
      expect(described_class.load_if_exists).to eq(valid_state)
    end
  end

  describe ".load_if_required!" do
    it "returns nil when strict mode is off and no session exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("INDEED_REQUIRE_SESSION", "false").and_return("false")
      expect(described_class.load_if_required!).to be_nil
    end

    it "raises when strict mode is on and no session exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("INDEED_REQUIRE_SESSION", "false").and_return("true")
      expect { described_class.load_if_required! }
        .to raise_error(Sourcing::Providers::Indeed::SessionNotFoundError, /required/)
    end
  end
end
