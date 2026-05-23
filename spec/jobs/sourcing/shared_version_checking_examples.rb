RSpec.shared_examples "skippable sourcing job with version checking" do
  before { allow(Sourcing::Pipeline).to receive(:advance) }

  it "skips step and asks Pipeline to advance when version matches and force is false" do
    offer_attrs = {
      source: "linkedin",
      url: "https://example.com/jobs/#{step_name}-skip",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/#{step_name}-skip"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      steps_details: {
        step_name => {
          "version" => 1,
          "at" => Time.current.iso8601,
        },
      },
    }

    offer = JobOffer.create!(offer_attrs)
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    ) if %w[analyze enrich].include?(step_name)

    call_count = 0
    allow_any_instance_of(mock_step_class).to receive(:call) do
      call_count += 1
      {}
    end

    described_class.perform_now(offer.id, force: false)

    expect(call_count).to eq(0)
    expect(Sourcing::Pipeline).to have_received(:advance).with(
      satisfy { |o| o.id == offer.id },
      force: false
    )
  end

  it "runs step and asks Pipeline to advance with force when force is true" do
    offer_attrs = {
      source: "linkedin",
      url: "https://example.com/jobs/#{step_name}-force",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/#{step_name}-force"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      steps_details: {
        step_name => {
          "version" => 1,
          "at" => Time.current.iso8601,
        },
      },
    }

    offer = JobOffer.create!(offer_attrs)
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    ) if %w[analyze enrich].include?(step_name)

    call_count = 0
    allow_any_instance_of(mock_step_class).to receive(:call) do
      call_count += 1
      case step_name
      when "fetch"
        "<html>updated</html>"
      when "analyze"
        { title: "Senior Backend Engineer", company: "NewCorp" }
      when "enrich"
        { normalized_seniority: "staff", primary_technologies: ["Rust", "Go"] }
      else
        {}
      end
    end

    described_class.perform_now(offer.id, force: true)

    expect(call_count).to eq(1)
    expect(Sourcing::Pipeline).to have_received(:advance).with(
      satisfy { |o| o.id == offer.id },
      force: true
    )
  end
end
