RSpec.shared_examples "skippable sourcing job with version checking" do
  it "skips step and enqueues next job if version matches and force is false" do
    # Setup offer with existing step details
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

    # Add html_file for steps that require it
    offer = JobOffer.create!(offer_attrs)
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    ) if %w[analyze enrich].include?(step_name)

    # Track calls to the step
    call_count = 0
    allow_any_instance_of(mock_step_class).to receive(:call) do
      call_count += 1
      {}
    end

    # Execute without force
    described_class.perform_now(url_hash: offer.url_hash, force: false)

    # Verify step was skipped
    expect(call_count).to eq(0)

    # Verify next job was enqueued with force propagated
    queued = enqueued_jobs.select { |job| job[:job] == next_job_class }
    expect(queued.size).to eq(1)
    expect(queued[0][:args].first).to include("url_hash" => offer.url_hash, "force" => false)
  end

  it "forces step execution even if version matches when force is true" do
    # Setup offer with existing step details
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

    # Add html_file for steps that require it
    offer = JobOffer.create!(offer_attrs)
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    ) if %w[analyze enrich].include?(step_name)

    # Track calls and return updated data
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

    # Execute with force=true
    described_class.perform_now(url_hash: offer.url_hash, force: true)

    # Verify step was executed
    expect(call_count).to eq(1)

    # Verify next job was enqueued with force propagated
    queued = enqueued_jobs.select { |job| job[:job] == next_job_class }
    expect(queued.size).to eq(1)
    expect(queued[0][:args].first).to include("url_hash" => offer.url_hash, "force" => true)
  end
end
