require "rails_helper"
require_relative "../session_manager_shared_examples"

RSpec.describe Sourcing::Providers::Indeed::SessionManager do
  it_behaves_like "a session manager" do
    let(:manager)             { described_class }
    let(:not_found_error)     { Sourcing::Providers::Indeed::SessionNotFoundError }
    let(:tmp_path)            { Rails.root.join("tmp", "indeed_session_spec.json") }
    let(:require_session_env) { "INDEED_REQUIRE_SESSION" }
  end
end
