FactoryBot.define do
  factory :period do
    name {"spring example year"}
    slug {"year"}
    organization {1}
    start_date {"2019-03-20"}
    duration {90}
    is_default {false}
  end
end
