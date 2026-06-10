# frozen_string_literal: true

module Types
  class LanguageRequirementType < Types::BaseObject
    field :language, String, null: false, description: "ISO 639-1 code (en, fr, de, ...)."
    field :level, Types::LanguageLevelEnum, null: false
  end
end
