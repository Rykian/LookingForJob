class RunJobOffer < ApplicationRecord
  belongs_to :run
  belongs_to :job_offer
end
