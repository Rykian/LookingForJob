FactoryBot.define do
  factory :job_offer do
    source { "linkedin" }
    sequence(:url) { |n| "https://example.com/offers/#{n}" }
    sequence(:url_hash) { |n| "hash-#{n}" }
    last_seen_at { Time.current }

    trait :remote do
      location_mode { "remote" }
    end

    trait :hybrid do
      location_mode { "hybrid" }
    end

    trait :on_site do
      location_mode { "on_site" }
    end

    trait :rejected do
      rejected { true }
    end

    trait :disabled do
      disabled { true }
    end

    trait :with_discovery_step do
      transient { discovered_at { 2.days.ago } }
      steps_details do
        { "discovery" => { "at" => discovered_at.iso8601, "version" => 1 } }
      end
    end

    trait :with_score do
      transient { value { 80 } }
      score { value }
    end
  end
end
