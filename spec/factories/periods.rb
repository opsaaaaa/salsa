FactoryBot.define do
  factory :period do
    name {Faker::Lorem.words}
    slug {Faker::Lorem.word}
    start_date {Faker::Date.between( Date.today, 1.year.from_now)}
    duration {90}
    is_default {false}
  end
end
