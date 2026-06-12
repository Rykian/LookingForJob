FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }

    trait :recruiter do
      posts_as_recruiter { true }
    end

    trait :final_client do
      posts_as_final_client { true }
    end

    trait :with_own_alias do
      after(:create) do |company|
        company.aliases.create!(name: company.name)
      end
    end
  end

  factory :company_alias do
    company
    sequence(:name) { |n| "Alias #{n}" }
  end
end
