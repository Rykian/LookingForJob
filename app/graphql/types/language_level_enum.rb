# frozen_string_literal: true

module Types
  class LanguageLevelEnum < Types::BaseEnum
    value "NOT_REQUIRED", value: "not_required", description: "Language mentioned in the offer but not required"
    value "BASIC", value: "basic", description: "Basic level required"
    value "PROFESSIONAL", value: "professional", description: "Professional level required"
    value "FLUENT", value: "fluent", description: "Fluent level required"
  end
end
