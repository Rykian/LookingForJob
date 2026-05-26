require "rails_helper"
require_relative "../session_manager_shared_examples"

RSpec.describe Sourcing::Providers::Cadremploi::SessionManager do
  it_behaves_like "a session manager" do
    let(:manager)         { described_class }
    let(:not_found_error) { Sourcing::Providers::Cadremploi::SessionNotFoundError }
    let(:tmp_path)        { Rails.root.join("tmp", "cadremploi_session_spec.json") }
  end
end
