module Sourcing
  module Concerns
    module OfferJobArguments
      private

      def find_offer(offer_id)
        JobOffer.find_by(id: offer_id)
      end

      def extract_force(options)
        return false if options.blank?

        options.to_h.symbolize_keys.fetch(:force, false)
      end
    end
  end
end
