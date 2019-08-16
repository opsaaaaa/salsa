FactoryBot.define do
  factory :organization do
    name {
      if Organization.find_by(name: "example").present?
        Faker::Company.unique.name
      else
        "example"
      end
    }
    slug {
      if Organization.find_by(slug: "localhost").present?
        Faker::Internet.unique.domain_name 
      else
        "localhost"
      end
    }
    default_account_filter {'{"account_filter":"FL17"}'}
    lms_authentication_source {}
    lms_authentication_key {Faker::Number.number(20)}
    lms_authentication_id {Faker::Number.number(10)}
  end
end
