FactoryBot.define do
  factory :oauth_session, class: 'OAuthSession' do
    association :user
    sequence(:access_token) { |n| "access_token_#{n}" }
    sequence(:refresh_token) { |n| "refresh_token_#{n}" }
    permissions { ['read', 'write'] }
    expires_at { 1.hour.from_now }
    sequence(:state) { |n| "state_#{n}" }
  end
end