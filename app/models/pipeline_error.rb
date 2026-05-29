class PipelineError < ApplicationRecord
  belongs_to :job_offer, optional: true
  belongs_to :run, optional: true

  scope :unresolved, -> { where(resolved: false) }
  scope :for_step, ->(step_name) { where(step: step_name) }
end
