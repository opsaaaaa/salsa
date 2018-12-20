require 'faker'

FactoryBot.define do
  factory :workflow_step do
    name {Faker::Name.unique.name}
    slug {Faker::Types.unique.rb_string.downcase}
    step_type { "default_step" }
    organization_id {1}
    after :create do |workflow_step|
      component = create :component, user_role: "admin", slug: workflow_step.slug, role: "staff", organization_id: workflow_step.organization_id
      workflow_step.component_id = component.id
      workflow_step.save
    end
  end
end
