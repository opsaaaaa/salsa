# 
# appearance steps
# 
# ie. the page should say...
# 

Then(/^I should not see "(.*?)"$/) do |string|
  expect(page).to have_no_content(string)
end

Then(/^I should be on the (\w+) page$/) do |string|
  expect(page.current_url).to have_content(string)
end

Then(/^I should see "(.*?)"$/) do |string|
  # expect(page).to have_content(string)
  expect(page).to have_content(string)
end

Then(/^there should be a "(.*?)" button$/) do |string|
#   raise page.current_url.to_yaml
  expect(page).to have_content(string)
end

Then(/^I should see "(.*?)" in the url$/) do |string|
  expect(page.current_url).to have_content(string)
end

Then(/^I should be able to see all the (\w+) for the organization$/) do |class_name|
  case class_name
  when /components/
    slugs = Component.where(organization_id: @organization.id).map(&:slug)
  when /workflow/
    slugs = WorkflowStep.where(organization_id: @organization.id).map(&:slug)
  when /periods/
    slugs = Period.where(organization_id: @organization.id).map(&:slug)
  end
  slugs.each do |slug|
    expect(page).to have_content(slug)
  end
end

Then(/^I should be able to see all the organizations$/) do
  slugs = Organization.all.map(&:name)
  slugs.each do |slug|
    expect(page).to have_content(slug)
  end
end

# Given("there is a {string}") do |table|
#   create
#   pending # Write code here that turns the phrase above into concrete actions
# end

Then("I should see a new document edit url") do
  expect(page.current_url).not_to have_content(@document.view_id)
end