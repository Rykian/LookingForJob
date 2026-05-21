SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/bin/"

  add_group "Models",      "app/models"
  add_group "Controllers", "app/controllers"
  add_group "GraphQL",     "app/graphql"
  add_group "Services",    "app/services"
  add_group "Jobs",        "app/jobs"
  add_group "Channels",    "app/channels"
  add_group "Subscribers", "app/subscribers"

  track_files "app/**/*.rb"
end
