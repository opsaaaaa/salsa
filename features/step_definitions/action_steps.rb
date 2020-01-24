# 
# action steps
# 
# ie. steps that preform actions as a user would
# 

When(/^I click on "(.*?)"$/) do |string|
  click_on(string)
end

When(/^I fill in the (\w+) form with:$/) do |record_name, table|
  # table is a Cucumber::Ast::Table
  table.raw.each do |field,value|
    id = "##{record_name}_#{field}"
    e = first(id)
    expect(e).not_to be_nil, "Unable to find #{id}"
    case tag = e.tag_name
    when 'input','textarea'
      e.set(value)
    when 'select'
      option = e.first(:option, value)
      expect(option).not_to be_nil, "Unable to find option #{value}"
      option.select_option
    else
      puts "pending: #{tag}"
      pending # duno how to handle that type of element
    end
  end
end

When(/^I click the "(.*?)" link$/) do |string|
  case string
  # when /(tb_share)/
  #   find(string).click
  #   @document.workflow_step_id = @document.workflow_step.next_workflow_step_id
  when /Edit Component/
    click_on("edit_#{@component.slug}")
  when /#edit_document/
    find(string).click
  when /#show_user/ 
    click_link("#{@user.name}")
  else
    click_link(string)
  end
end
