module Sourcing
  module PlaywrightSupport
    private

    def playwright_cli_executable_path
      version = Gem.loaded_specs.fetch("playwright-ruby-client").version.to_s
      "npx -y playwright@#{version}"
    end
  end
end