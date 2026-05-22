require "rails_helper"

RSpec.describe Sourcing::Providers::Linkedin::Parsers::PostedAt do
  let(:now) { Time.utc(2026, 5, 21, 12, 0, 0) }

  def parse(raw)
    described_class.call(raw, now: now)
  end

  it "returns nil for blank/nil input" do
    expect(parse(nil)).to be_nil
    expect(parse("")).to be_nil
    expect(parse("   ")).to be_nil
  end

  it "returns now for 'just now'" do
    expect(parse("Just now")).to eq("2026-05-21T12:00:00Z")
  end

  it "subtracts minutes" do
    expect(parse("15 minutes ago")).to eq("2026-05-21T11:45:00Z")
  end

  it "subtracts hours" do
    expect(parse("3 hours ago")).to eq("2026-05-21T09:00:00Z")
  end

  it "subtracts days" do
    expect(parse("2 days ago")).to eq("2026-05-19T12:00:00Z")
  end

  it "subtracts weeks" do
    expect(parse("1 week ago")).to eq("2026-05-14T12:00:00Z")
  end

  it "subtracts months (approx 30 days)" do
    expect(parse("3 months ago")).to eq("2026-02-20T12:00:00Z")
  end

  it "subtracts years (approx 365 days)" do
    expect(parse("1 year ago")).to eq("2025-05-21T12:00:00Z")
  end

  it "returns nil for unrecognized input" do
    expect(parse("yesterday at noon")).to be_nil
    expect(parse("posted on 2026-01-01")).to be_nil
  end
end
