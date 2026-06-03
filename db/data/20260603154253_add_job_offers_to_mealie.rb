# frozen_string_literal: true

class AddJobOffersToMealie < ActiveRecord::Migration[8.1]
  def up
    JobOffer.ms_reindex!
  end

  def down
  end
end
