class Run < ApplicationRecord
  has_many :run_job_offers, dependent: :delete_all
  has_many :job_offers, through: :run_job_offers
end
