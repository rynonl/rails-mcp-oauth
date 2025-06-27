FactoryBot.define do
  factory :user do
    sequence(:workos_id) { |n| "workos_user_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "John" }
    last_name { "Doe" }
    profile_picture_url { "https://example.com/avatar.jpg" }
    organization_id { "org_123" }
  end
end