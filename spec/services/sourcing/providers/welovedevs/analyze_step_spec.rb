require "rails_helper"

RSpec.describe Sourcing::Providers::Welovedevs::AnalyzeStep do
  subject(:step) { described_class.new }

  it "inherits from Sourcing::AnalyzeStep" do
    expect(step).to be_a(Sourcing::AnalyzeStep)
  end

  # Mirrors a real WeLoveDevs offer page: a JSON-LD JobPosting plus the templated
  # meta description used as a secondary signal.
  let(:full_html) do
    <<~HTML
      <html>
        <head>
          <meta name="description" content="DataDome is looking for a Back-end developer in Permanent contract. Location: 100% remote working. Salaire 45k to 55k. Find the best IT job offers on WeLoveDevs.com">
          <script type="application/ld+json">
            {
              "@context": "http://schema.org",
              "@type": "JobPosting",
              "title": "Backend Engineer w/m ",
              "hiringOrganization": { "@type": "Organization", "name": "DataDome" },
              "jobLocation": { "@type": "Place", "address": { "@type": "PostalAddress", "addressCountry": "FR", "addressLocality": "Paris", "addressRegion": "Île-de-France" } },
              "jobLocationType": "TELECOMMUTE",
              "employmentType": ["FULL_TIME"],
              "baseSalary": { "@type": "MonetaryAmount", "currency": "EUR", "value": { "@type": "QuantitativeValue", "minValue": 45000, "maxValue": 55000, "unitText": "YEAR" } },
              "datePosted": "2026-06-05",
              "validThrough": "2026-07-05",
              "description": "<p style=\\"color:red\\" class=\\"intro\\"><strong>About the team</strong></p><p>Build robust APIs in Go.</p><script>console.log(\\"noise\\")<\\/script>"
            }
          </script>
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[]}
          </script>
        </head>
        <body><h1>Backend Engineer w/m</h1></body>
      </html>
    HTML
  end

  describe "#call" do
    let(:result) { step.call(html_content: full_html) }

    it "extracts and trims the title from JSON-LD" do
      expect(result[:title]).to eq("Backend Engineer w/m")
    end

    it "extracts the company from hiringOrganization.name" do
      expect(result[:company]).to eq("DataDome")
    end

    it "extracts the city from jobLocation.address.addressLocality" do
      expect(result[:city]).to eq("Paris")
    end

    it "prefers the precise contract from the meta description over the coarse JSON-LD employmentType" do
      expect(result[:employment_type]).to eq("PERMANENT")
    end

    it "extracts salary from the JSON-LD MonetaryAmount" do
      expect(result[:salary_min_minor]).to eq(45_000)
      expect(result[:salary_max_minor]).to eq(55_000)
      expect(result[:salary_currency]).to eq("EUR")
    end

    it "maps jobLocationType TELECOMMUTE to remote" do
      expect(result[:location_mode]).to eq("remote")
    end

    it "extracts posted_at from datePosted" do
      expect(result[:posted_at]).to eq("2026-06-05")
    end

    it "returns description HTML stripped of scripts and style/class attributes" do
      expect(result[:description_html]).to include("About the team", "Build robust APIs in Go")
      expect(result[:description_html]).not_to include("console.log")
      expect(result[:description_html]).not_to include("style=")
      expect(result[:description_html]).not_to include("class=")
    end
  end

  describe "JSON-LD fallbacks" do
    it "falls back to the coarse JSON-LD employmentType when no contract keyword is in the meta description" do
      html = full_html.sub("in Permanent contract. ", "")
      expect(step.call(html_content: html)[:employment_type]).to eq("FULL_TIME")
    end

    it "converts a MONTH-based salary unit to a yearly amount" do
      html = full_html.sub('"unitText": "YEAR"', '"unitText": "MONTH"').sub('"minValue": 45000', '"minValue": 4000').sub('"maxValue": 55000', '"maxValue": 5000')
      result = step.call(html_content: html)
      expect(result[:salary_min_minor]).to eq(48_000)
      expect(result[:salary_max_minor]).to eq(60_000)
    end
  end

  describe "location_mode from remotePolicy.frequency (fallback for chip-less offers)" do
    def html_with_frequency(frequency)
      <<~HTML
        <html>
          <head>
            <meta name="description" content="Crypto.com is looking for a Lead developer in Permanent contract. Location: Canada. Salaire .">
            <script type="application/ld+json">{ "@type": "JobPosting", "title": "Senior Java Developer" }</script>
          </head>
          <body>
            <script>self.__next_f.push([1,"...\\"remotePolicy\\":{\\"frequency\\":\\"#{frequency}\\"}..."])</script>
          </body>
        </html>
      HTML
    end

    it "maps frequency 'no' to on-site (the chip-less case the DOM can't see)" do
      expect(step.call(html_content: html_with_frequency("no"))[:location_mode]).to eq("on-site")
    end

    it "maps frequency 'hybrid' to hybrid" do
      expect(step.call(html_content: html_with_frequency("hybrid"))[:location_mode]).to eq("hybrid")
    end

    it "maps frequency 'fullTime' to remote" do
      expect(step.call(html_content: html_with_frequency("fullTime"))[:location_mode]).to eq("remote")
    end
  end

  describe "location_mode from the remote chip (primary, distinguishes occasional from hybrid)" do
    # A hybrid offer with no remotePolicy and no jobLocationType — the header chip carries
    # the mode (the real bug from offer 163582 / Crypto.com).
    def html_with_chip(chip_text)
      <<~HTML
        <html>
          <head>
            <meta name="description" content="Crypto.com is looking for a Lead developer in Permanent contract. Location: Canada. Salaire .">
            <script type="application/ld+json">
              { "@type": "JobPosting", "title": "Senior Java Developer", "jobLocation": { "address": { "addressCountry": "CA" } } }
            </script>
          </head>
          <body>
            <a class="flex items-center" href="/app/job-remote"><span class="text-sm underline">#{chip_text}</span></a>
          </body>
        </html>
      HTML
    end

    it "detects hybrid from a 'Hybrid teleworking (2 weekdays)' chip" do
      expect(step.call(html_content: html_with_chip("Hybrid teleworking (2 weekdays)"))[:location_mode]).to eq("hybrid")
    end

    it "detects hybrid from a 'Regular remote work' chip" do
      expect(step.call(html_content: html_with_chip("Regular remote work"))[:location_mode]).to eq("hybrid")
    end

    it "treats 'Occasional remote work' as on-site, not hybrid" do
      expect(step.call(html_content: html_with_chip("Occasional remote work"))[:location_mode]).to eq("on-site")
    end

    it "lets the chip win over remotePolicy for occasional remote (chip on-site beats frequency 'hybrid')" do
      html = <<~HTML
        <html>
          <head><script type="application/ld+json">{ "@type": "JobPosting", "title": "X" }</script></head>
          <body>
            <a href="/app/job-remote"><span>Occasional remote work</span></a>
            <script>self.__next_f.push([1,"...\\"remotePolicy\\":{\\"frequency\\":\\"hybrid\\"}..."])</script>
          </body>
        </html>
      HTML
      expect(step.call(html_content: html)[:location_mode]).to eq("on-site")
    end

    it "detects remote from a '100% Teleworking' chip" do
      expect(step.call(html_content: html_with_chip("100% Teleworking"))[:location_mode]).to eq("remote")
    end

    it "ignores a generic 'Remote IT jobs' category link (no specific mode)" do
      expect(step.call(html_content: html_with_chip("Remote IT jobs"))[:location_mode]).to be_nil
    end
  end

  describe "missing-field tolerance" do
    it "returns nil for fields when no JSON-LD is present, without raising" do
      result = step.call(html_content: "<html><body><h1>Some Title</h1></body></html>")
      expect(result[:title]).to eq("Some Title")
      expect(result[:company]).to be_nil
      expect(result[:city]).to be_nil
      expect(result[:employment_type]).to be_nil
      expect(result[:salary_min_minor]).to be_nil
      expect(result[:location_mode]).to be_nil
      expect(result[:posted_at]).to be_nil
      expect(result[:description_html]).to be_nil
    end
  end
end
