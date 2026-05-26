RSpec.shared_examples "a session manager" do
  # Requires the including context to define:
  #   let(:manager)         - the SessionManager class
  #   let(:not_found_error) - the provider's SessionNotFoundError class
  #   let(:tmp_path)        - writable tmp path for the session file

  let(:valid_state) { { "cookies" => [], "origins" => [] } }

  before do
    allow(manager).to receive(:path).and_return(tmp_path)
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

  describe ".provider_name" do
    it "returns the lowercase provider module name" do
      expect(manager.provider_name).to eq(manager.name.split("::")[2].downcase)
    end
  end

  describe ".login_command" do
    it "includes the provider name" do
      expect(manager.login_command).to eq("bin/rails #{manager.provider_name}:login")
    end
  end
end
