RSpec.shared_examples "a session manager" do
  # Requires the including context to define:
  #   let(:manager)            - the SessionManager class
  #   let(:not_found_error)    - the provider's SessionNotFoundError class
  #   let(:tmp_path)           - writable tmp path used to stub SESSION_PATH
  #   let(:require_session_env) - env var name (e.g. "INDEED_REQUIRE_SESSION")

  let(:valid_state) { { "cookies" => [], "origins" => [] } }

  before do
    stub_const("#{manager}::SESSION_PATH", tmp_path)
    FileUtils.rm_f(tmp_path)
  end

  after { FileUtils.rm_f(tmp_path) }

  describe ".save / .load" do
    it "roundtrips valid storage state" do
      manager.save(valid_state)
      expect(manager.load).to eq(valid_state)
    end

    it "raises on missing required keys" do
      expect { manager.save({ "cookies" => [] }) }
        .to raise_error(not_found_error, /origins/)
    end

    it "raises when the file is invalid JSON" do
      File.write(tmp_path, "not json")
      expect { manager.load }.to raise_error(not_found_error, /invalid JSON/)
    end
  end

  describe ".load_if_exists" do
    it "returns nil when no file is present" do
      expect(manager.load_if_exists).to be_nil
    end

    it "returns the parsed state when present" do
      manager.save(valid_state)
      expect(manager.load_if_exists).to eq(valid_state)
    end
  end

  describe ".load_if_required!" do
    it "returns nil when strict mode is off and no session exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with(require_session_env, "false").and_return("false")
      expect(manager.load_if_required!).to be_nil
    end

    it "raises when strict mode is on and no session exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with(require_session_env, "false").and_return("true")
      expect { manager.load_if_required! }.to raise_error(not_found_error, /required/)
    end
  end
end
