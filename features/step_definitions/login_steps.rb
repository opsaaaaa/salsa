Given(/^that I am logged in as a (\w+) on the organization$/) do |role|
  visit "/admin/login"
  @current_user = FactoryBot.create(:user)
  user_assignment = create(:user_assignment, user_id: @current_user.id, role: role, organization_id: @organization.id)
  fill_in "user_email", :with => @current_user.email
  fill_in "user_password", :with => @current_user.password
  click_button("Log in")
  expect(page).to have_content("Logged in successfully")
end

Given(/^that I am logged in as a (\w+)$/) do |role|
  visit "/admin/login"
  @current_user = FactoryBot.create(:user)
  user_assignment = create(:user_assignment, user_id: @current_user.id, role: role)
  fill_in "user_email", :with => @current_user.email
  fill_in "user_password", :with => @current_user.password
  click_button("Log in")
  expect(page).to have_content("Logged in successfully")
end

Given("that i am logged in as a supervisor") do
  pending # Write code here that turns the phrase above into concrete actions
end

Given(/^I am the (\w+) of the user$/) do |role|
  Assignment.create(user_id: @current_user.id, team_member_id: @user.id, role: role)
end
