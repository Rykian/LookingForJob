module Sourcing
  module Concerns
    module VersionChecking
      # Check if a step should be skipped based on version comparison
      # Returns true if step should be skipped, false if it should be executed
      #
      # @param offer [JobOffer] the job offer record
      # @param step_name [String] the name of the step (e.g., 'fetch', 'analyze')
      # @param current_version [Integer] the current VERSION constant from the step class
      # @param force [Boolean] whether to force execution regardless of version
      # @return [Boolean] true if step should be skipped, false if it should run
      def should_skip_step?(offer, step_name, current_version, force: false)
        return false if force

        stored_step_details = offer.steps_details[step_name]
        return false if stored_step_details.blank?

        stored_version = stored_step_details["version"]
        stored_version == current_version
      end
    end
  end
end
