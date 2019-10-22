FactoryBot.define do
  factory :sub_organization, class: Organization do
    name {Faker::App.name}
    slug {"/#{Faker::Lorem.unique.word}"}
    parent_id {FactoryBot.create(:organization).id}
  end
end
