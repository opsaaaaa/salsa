# 
# construction steps
# 
# ie. steps that build things can call factories
# 

Given(/^there is a organization with a sub organization$/) do
  @organization = FactoryBot.create(:organization)
  @sub_organization = FactoryBot.create(:organization, parent_id: @organization.id)
end

Given(/^there is a "(.*?)" with:$/) do |class_name, table|
  instance_variable_set( "@#{class_name}",
    class_name.classify.safe_constantize
    .create( Hash[ *table.raw.flatten(1) ] ) )
end

Given(/^the "(.*?)" has:$/) do |class_name, table|
  record = instance_variable_get("@#{class_name}")
  update_hash = Hash[ *table.raw.flatten(1) ]
  record.update update_hash
  expect(class_name.classify.safe_constantize
    .find_by(update_hash).present?)
      .to eq(true)
end

Given(/^the "(.*?)" has a "(.*?)" with:$/) do |parent_var_name, child_class_name, table|
  hash = Hash[ *table.raw.flatten(1) ]
  parent_record = instance_variable_get("@#{parent_var_name}")
  hash["#{parent_record.class}_id".downcase] = parent_record.id
  instance_variable_set( "@#{child_class_name}",
    child_class_name.classify.safe_constantize.create( hash ) )
end

Given(/^the "(.*?)" has a "(.*?)"$/) do |parent_var_name, factory_name|
  factory_name = factory_name.to_sym
  parent_record = instance_variable_get("@#{parent_var_name}")
  record = FactoryBot.create(factory_name,"#{parent_record.class}_id".downcase.to_sym=>parent_record.id)
  instance_variable_set( "@#{record.class.name.downcase}", record)
  expect(record.present? && !record.new_record? && record.is_a?(Document))
      .to eq(true)
end

Given(/^the "(.*?)" belongs to the "(.*?)"$/) do |child_var_name, parent_var_name|
  parent_record = instance_variable_get("@#{parent_var_name}")
  child_record = instance_variable_get("@#{child_var_name}")
  child_record["#{parent_record.class}_id".downcase] = parent_record.id
  child_record.save!
  instance_variable_set( "@#{child_var_name}", child_record)
end

Given(/^there is a (\w+) with a (\w+) of "(.*?)"$/) do |class_name, field_name, field_value|
  instance_variable_set("@#{class_name}", create(class_name, field_name => field_value))
end

Given(/^there is a (\w+) with a (\w+) of (\w+)$/) do |class_name, field, value|
  record = create(class_name, feild => value)
  instance_variable_set("@#{class_name}",record)
end

Given(/^there is a user with the role of (\w+)$/) do |role|
  user = FactoryBot.create(:user)
  user_assignment = create(:user_assignment, user_id: user.id, role: role, organization_id: @organization.id)
  instance_variable_set("@user",user)
end

Given(/^there is a (\w+) on the organization$/) do |class_name|
  case class_name
  when /user/
    record = create(class_name.singularize)
    record_assignment = create('user_assignment', user: record, organization: @organization)
  when /component/
    record = create(class_name, organization_id: @organization.id, user_role: "admin")
  else
    record = create(class_name, organization_id: @organization.id)
  end
  instance_variable_set("@#{class_name}",record)
end

Given(/^there are (\d+) (\w+) for the organization/) do | number, class_name|
  case class_name
  when /users/
    record = create(class_name.singularize)
    record_assignment = create('user_assignment', user: record, organization: @organization)
  when /components/
    record = create(class_name.singularize, organization: @organization, user_role: "admin")
  else
    record = create(class_name.singularize, organization: @organization)
  end
  instance_variable_set("@#{class_name}",record)
end

Given(/^there is a user with the role of (\w+) on the sub organization$/) do |role|
  user = FactoryBot.create(:user)
  user_assignment = create(:user_assignment, user_id: user.id, role: role, organization_id: @sub_organization.id)
  instance_variable_set("@user",user)
end

Given("there are documents with document_metas that match the filter") do
  doc = create(:document, organization_id: @organization.id)
end

Given(/^there are (\w+) (\w+)$/) do |amount, class_name|
  record = create_list(class_name, amount.to_i)
  instance_variable_set("@#{class_name.pluralize}",record)
end

Given(/^there is a (\w+) period$/) do |name|
  period = FactoryBot.create( :period, 
    organization_id: @organization.id, is_default: (name == 'default')
  )
  instance_variable_set("@#{name}_period",period)
end