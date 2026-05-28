require "rails_helper"

RSpec.describe Sourcing::Providers::Wttj::DiscoveryStep do
  subject(:step) { described_class.new(connection: fake_connection) }

  it "inherits from Sourcing::DiscoveryStep" do
    expect(described_class.new).to be_a(Sourcing::DiscoveryStep)
  end

  describe "#supports_work_mode_filter?" do
    it "returns false (sitemap has no work_mode metadata)" do
      expect(described_class.new.supports_work_mode_filter?).to be false
    end
  end

  describe "#call" do
    let(:lastmod_recent) { (Time.now - 2 * 86_400).iso8601 }
    let(:lastmod_old)    { (Time.now - 60 * 86_400).iso8601 }

    let(:sitemap_xml) do
      <<~XML
        <?xml version="1.0"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url>
            <loc>https://www.welcometothejungle.com/fr/companies/bluecoders/jobs/senior-rails-engineer_paris</loc>
            <lastmod>#{lastmod_recent}</lastmod>
          </url>
          <url>
            <loc>https://www.welcometothejungle.com/fr/companies/oldco/jobs/old-job_lyon</loc>
            <lastmod>#{lastmod_old}</lastmod>
          </url>
          <url>
            <loc>https://www.welcometothejungle.com/en/companies/anywhereco/jobs/english-only_london</loc>
            <lastmod>#{lastmod_recent}</lastmod>
          </url>
          <url>
            <loc>https://www.welcometothejungle.com/fr/companies/dataco/jobs/data-engineer_paris</loc>
            <lastmod>#{lastmod_recent}</lastmod>
          </url>
        </urlset>
      XML
    end

    let(:gzipped_body) do
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(sitemap_xml)
      gz.close
      io.string
    end

    let(:fake_connection) do
      Faraday.new do |f|
        f.adapter :test do |stub|
          (0..Sourcing::Providers::Wttj::DiscoveryStep::MAX_SITEMAP_INDEX).each do |index|
            url = "#{Sourcing::Providers::Wttj::DiscoveryStep::SITEMAP_BASE}.#{index}.xml.gz"
            stub.get(url) do
              body = index.zero? ? gzipped_body : empty_sitemap_gzipped
              [200, { "Content-Type" => "application/xml" }, body]
            end
          end
        end
      end
    end

    let(:empty_sitemap_gzipped) do
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write('<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>')
      gz.close
      io.string
    end

    before do
      allow(Sourcing::Providers::Wttj::SessionManager).to receive(:exists?).and_return(false)
    end

    it "filters out non-/fr/ URLs" do
      result = step.call(days: 30)
      expect(result[:discovered_urls]).not_to include(match(%r{/en/companies/}))
    end

    it "filters out URLs older than the recency window" do
      result = step.call(days: 7)
      expect(result[:discovered_urls]).not_to include(match(/old-job/))
    end

    it "keeps recent French URLs" do
      result = step.call(days: 7)
      expect(result[:discovered_urls]).to include(
        "https://www.welcometothejungle.com/fr/companies/bluecoders/jobs/senior-rails-engineer_paris",
        "https://www.welcometothejungle.com/fr/companies/dataco/jobs/data-engineer_paris"
      )
    end

    it "applies the keyword slug filter" do
      result = step.call(days: 7, keyword: "rails")
      expect(result[:discovered_urls]).to include(match(/senior-rails-engineer/))
      expect(result[:discovered_urls]).not_to include(match(/data-engineer/))
    end

    it "does not invoke jobs-matches when no session exists" do
      expect(step).not_to receive(:discover_from_jobs_matches)
      step.call(days: 7)
    end
  end
end
