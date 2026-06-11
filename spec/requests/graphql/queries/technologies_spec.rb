require "rails_helper"

RSpec.describe "GraphQL query technologies", type: :request do
  # Common technologies live in Redis (written by CanonicalizeTechnologiesJob); stub
  # the store so these tests don't depend on a populated Redis.
  before do
    allow(Sourcing::TechnologyStore).to receive(:read_common_technologies)
      .and_return(["Python", "TypeScript", "Go"])
  end

  it "returns only primary technologies when includePrimary is set" do
    profile_path = Rails.root.join("tmp", "test_scoring_profile.json")

    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", profile_path)

    profile = {
      technology: {
        primary: ["Ruby", "Rails"],
        secondary: ["PostgreSQL"],
      },
      location: {
        preference: ["remote"],
      },
    }

    File.write(profile_path, JSON.generate(profile))
    Sourcing::ScoringProfile.reload!

    query = <<~GRAPHQL
      query {
        technologies(includePrimary: true)
      }
    GRAPHQL

    result = post_graphql(query: query)

    expect(result["errors"]).to be_nil
    technologies = result.dig("data", "technologies")
    expect(technologies).to eq(["Ruby", "Rails"])
    expect(technologies).not_to include("Python", "TypeScript", "Go")
  ensure
    File.delete(profile_path) if File.exist?(profile_path)
  end

  it "deduplicates technologies that appear in both profile and common list" do
    profile_path = Rails.root.join("tmp", "test_scoring_profile.json")

    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", profile_path)

    profile = {
      technology: {
        primary: ["Ruby", "Python"],
        secondary: [],
      },
      location: {
        preference: ["remote"],
      },
    }

    File.write(profile_path, JSON.generate(profile))
    Sourcing::ScoringProfile.reload!

    query = <<~GRAPHQL
      query {
        technologies
      }
    GRAPHQL

    result = post_graphql(query: query)

    expect(result["errors"]).to be_nil
    technologies = result.dig("data", "technologies")
    expect(technologies.count("Python")).to eq(1)
  ensure
    File.delete(profile_path) if File.exist?(profile_path)
  end

  it "returns only common technologies when profile has no primary technologies" do
    profile_path = Rails.root.join("tmp", "test_scoring_profile.json")

    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", profile_path)

    profile = {
      technology: {
        primary: [],
        secondary: [],
      },
      location: {
        preference: ["remote"],
      },
    }

    File.write(profile_path, JSON.generate(profile))
    Sourcing::ScoringProfile.reload!

    query = <<~GRAPHQL
      query {
        technologies
      }
    GRAPHQL

    result = post_graphql(query: query)

    expect(result["errors"]).to be_nil
    technologies = result.dig("data", "technologies")
    expect(technologies).to be_an(Array)
    expect(technologies).to include("Python", "TypeScript", "Go")
  ensure
    File.delete(profile_path) if File.exist?(profile_path)
  end

  context "with explicit arguments" do
    let(:profile_path) { Rails.root.join("tmp", "test_scoring_profile_args.json") }

    before do
      stub_const("Sourcing::ScoringProfile::PROFILE_PATH", profile_path)
      profile = {
        technology: { primary: ["Ruby", "Rails"], secondary: ["PostgreSQL"] },
        location: { preference: ["remote"] },
      }
      File.write(profile_path, JSON.generate(profile))
      Sourcing::ScoringProfile.reload!
    end

    after do
      File.delete(profile_path) if File.exist?(profile_path)
      Sourcing::ScoringProfile.instance_variable_set(:@cached, nil)
    end

    it "includePrimary: true returns only primary technologies" do
      result = post_graphql(query: "query { technologies(includePrimary: true) }")

      expect(result["errors"]).to be_nil
      technologies = result.dig("data", "technologies")
      expect(technologies).to eq(["Ruby", "Rails"])
      expect(technologies).not_to include("Python", "TypeScript", "Go")
    end

    it "includeSecondary: true returns only secondary technologies" do
      result = post_graphql(query: "query { technologies(includeSecondary: true) }")

      expect(result["errors"]).to be_nil
      technologies = result.dig("data", "technologies")
      expect(technologies).to eq(["PostgreSQL"])
      expect(technologies).not_to include("Python", "TypeScript", "Go")
    end

    it "includeCommon: true returns only common technologies" do
      result = post_graphql(query: "query { technologies(includeCommon: true) }")

      expect(result["errors"]).to be_nil
      technologies = result.dig("data", "technologies")
      expect(technologies).to eq(["Python", "TypeScript", "Go"])
      expect(technologies).not_to include("Ruby", "Rails", "PostgreSQL")
    end

    it "includePrimary and includeSecondary returns profile technologies only" do
      result = post_graphql(query: "query { technologies(includePrimary: true, includeSecondary: true) }")

      expect(result["errors"]).to be_nil
      technologies = result.dig("data", "technologies")
      expect(technologies).to eq(["Ruby", "Rails", "PostgreSQL"])
      expect(technologies).not_to include("Python", "TypeScript", "Go")
    end
  end
end
