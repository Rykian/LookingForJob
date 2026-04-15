require "rails_helper"

RSpec.describe Sourcing::RelevanceChecker do
  subject(:checker) { described_class.new }

  describe "#call" do
    it "matches a single keyword as a full token" do
      html = "<div>We are hiring a Ruby backend engineer.</div>"

      expect(checker.call(["ruby"], html)).to eq(true)
    end

    it "does not match substring-only values" do
      html = "<div>Looking for JavaScript developers.</div>"

      expect(checker.call(["java"], html)).to eq(false)
    end

    it "matches a multi-word phrase with boundaries" do
      html = "<section>Senior Data Engineer role in Paris.</section>"

      expect(checker.call(["data engineer"], html)).to eq(true)
    end

    it "normalizes punctuation and case" do
      html = "<p>Senior, RUBY-on-RAILS developer needed.</p>"

      expect(checker.call(["Ruby On Rails"], html)).to eq(true)
    end

    it "supports symbol aliases" do
      html = "<p>Strong C# and .NET experience expected.</p>"

      expect(checker.call(["c#"], html)).to eq(true)
      expect(checker.call([".net"], html)).to eq(true)
    end

    it "uses loose mode and returns true when any keyword matches" do
      html = "<p>Staff Ruby engineer role.</p>"

      expect(checker.call(["java", "ruby"], html)).to eq(true)
    end

    it "ignores blank keywords after normalization" do
      html = "<p>Backend role.</p>"

      expect(checker.call(["***", "   "], html)).to eq(true)
    end
  end
end
