FactoryBot.define do
  factory :organizations, class: Organization do
    name {Faker::App.name}
    slug {Faker::Code.asin.downcase}
    default_account_filter {'{"account_filter":"FL17"}'}
    lms_authentication_source {""}
    lms_authentication_key {Faker::Number.number(20)}
    lms_authentication_id {Faker::Number.number(10)}
  end
end
