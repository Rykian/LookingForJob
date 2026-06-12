class CompanyAlias < ApplicationRecord
  belongs_to :company, inverse_of: :aliases

  before_validation :set_normalized_name

  validates :name, :normalized_name, presence: true
  # Uniqueness is enforced by the DB unique index on normalized_name; a Rails
  # uniqueness validation would race under concurrent CompanyJobs (see
  # Commute::City for the rationale).

  private

  def set_normalized_name
    self.normalized_name = Company.normalize(name) if name.present? && normalized_name.blank?
  end
end
