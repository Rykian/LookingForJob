namespace :sourcing do
  desc "Enqueue discovery launches for all providers using KEYWORDS and WORK_MODE"
  task launch_discovery: :environment do
    Sourcing::LaunchDiscoveryJob.perform_later

    puts "Enqueued Sourcing::LaunchDiscoveryJob"
  end
end
