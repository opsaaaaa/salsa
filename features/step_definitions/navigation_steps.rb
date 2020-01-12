# 
# navigation steps
# 
# ie. something built to visit a page
# 

When(/^i visit the document new page with:$/) do |params|
    visit new_document_path( Hash[*params.raw.flatten(1)] )
end

When(/^i visit that documents template page with:$/) do |params|
    visit template_document_path( 
        Hash[*params.raw.flatten(1)].merge(
            { id: @document.template_id }
        ) 
    )
end

When(/^i visit the new document page$/) do |params|
    visit new_document_path
end

When(/^I search documents for "(.*?)"$/) do |search|
  visit documents_search_path(org_path: @organization.slug, slug: @organization.full_slug, q: search)
end

When("I go to the document edit page for the users document") do
  visit edit_document_path(:id => @document.edit_id)
end

Given("I am on the admin reports page for organization") do
  visit "/admin/reports"
  expect(page).to have_content("Reports for")
end

Given(/^I am on the (\w+) index page for the organization$/) do |controller|
  @controller = controller
  url = "/admin/organization/#{@organization.slug}/#{controller}"
  visit url
end

Then(/^I should be on the (\w+) document page$/) do |string|
  case string
  when /view/
    expect(page.current_url).to have_content(@document.view_id)
  when /edit/
    expect(page.current_url).to have_content(string)
  else
    pending
  end
end

Given(/^I am on the "(.*?)" page$/) do |page|
  case page
  when /edit_workflow_document/
    visit edit_document
  else
    visit page
  end
end

Given(/^I am on the organization (\w+) page$/) do |action|
  case action
  when /show/
    visit organization_path(@organization.slug)
  when /index/
    visit organizations_path
  when /edit/
    visit edit_organization_path(id: @organization[:id], org_path: @organization.slug, slug: @organization.slug)
  when /new/
    visit new_organization_path(org_path: @organization.slug)
  when /delete/
    page.driver.delete(organization_path(@organization.slug))
  end
end

Given(/^I am on the (\w*document\b) (\w+) page$/) do |document_type, page_path|
  case document_type
  when /canvas_document/
    pending
    # FakeWeb.register_uri(:any, "#{@organization.lms_authentication_source}/login/oauth2/auth", :body => "Authorizing", :data => {"access_token":"MTQ0NjJkZmQ5OTM2NDE1ZTZjNGZmZjI3","refresh_token":"IwOGYzYTlmM2YxOTQ5MGE3YmNmMDFkNTVk","state":"12345678"})
    # visit "http://lvh.me:#{Capybara.current_session.port}#{lms_course_document_path(@document.lms_course_id)}"
    # save_page
  when /document/
    visit edit_document_path(@document.edit_id)
  else
    pending
  end
end