# 
# inspection steps 
# 
# ie. steps that test the records
# 

Then("the document should be associated with my user") do
  expect(Document.find(@document.id).user_id).to eq(@current_user.id)
end

Then(/^the "(.*?)" should be (present|absent)$/) do |class_name, should_be|
  record = instance_variable_get("@#{class_name}")
  expect(class_name.classify.safe_constantize
    .find_by(id: record.id).present?)
      .to eq(should_be == "present")
end

Then(/^an "(.*?)" should be (present|absent) with:$/) do |class_name, should_be, table|
  record = class_name.classify.safe_constantize
  record = class_name.safe_constantize if record.nil?
  present_record = record.find_by(Hash[*table.raw.flatten(1)])
  expect(present_record.present?).to eq(should_be == "present")
  instance_variable_set( "@#{class_name}", present_record )
end

Then(/^the (\w+) (\w+) should be (\w+)$/) do |class_name, record_name, value|
  record = instance_variable_get("@#{class_name}")
  result = record.send(record_name)
  case value
  when /nil/
    expect(result).to be nil
  else
    expect(result).to have_content(value)
  end
end

Then('the new document should belong to the default period') do
  expect(@document.period).to eq(@default_period)
end

Then('a new templated document should exist') do 
  old_document = @organization.documents.find(@document.id)
end