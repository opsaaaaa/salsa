# 
# workflow step
# 

Given("the user has a document with a workflow_step of {int}") do |int|
  @document = create(:document, organization_id: @organization.id, user_id: @user.id, workflow_step_id: @workflows.first[int.to_i-1].id)
end

Given(/^there is a document on the (\w+) step in the workflow and assigned to the user on the sub org$/) do |step|
  case step
  when /first/
    @document = create(:document, workflow_step_id: @workflows.first.first.id, user_id: @user.id, organization_id: @sub_organization.id)
  when /second/
    @document = create(:document, workflow_step_id: @workflows.first[1].id, user_id: @user.id, organization_id: @sub_organization.id)
  when /fourth/
    @document = create(:document, workflow_step_id: @workflows.first[3].id, user_id: @user.id, organization_id: @sub_organization.id)
  when /last/
    @document = create(:document, workflow_step_id: @workflows.first.last.id, user_id: @user.id, organization_id: @sub_organization.id)
  else
    pending
  end
end

Given(/^there is a document on the (\w+) step in the workflow and assigned to the current user$/) do |step|
  case step
  when /first/
    @document = create(:document, workflow_step_id: @workflows.first.first.id, user_id: @current_user.id, organization_id: @organization.id)
  when /second/
    @document = create(:document, workflow_step_id: @workflows.first[1].id, user_id: @current_user.id, organization_id: @organization.id)
  when /fourth/
    @document = create(:document, workflow_step_id: @workflows.first[3].id, user_id: @current_user.id, organization_id: @organization.id)
  when /last/
    @document = create(:document, workflow_step_id: @workflows.first.last.id, user_id: @current_user.id, organization_id: @organization.id)
  else
    pending
  end
end

Given(/^there is a document on the (\w+) step in the workflow and assigned to the user$/) do |step|
  case step
  when /first/
    @document = create(:document, workflow_step_id: @workflows.first.first.id, user_id: @user.id, organization_id: @organization.id)
  when /second/
    @document = create(:document, workflow_step_id: @workflows.first[1].id, user_id: @user.id, organization_id: @organization.id)
  when /fourth/
    @document = create(:document, workflow_step_id: @workflows.first[3].id, user_id: @user.id, organization_id: @organization.id)
  when /last/
    @document = create(:document, workflow_step_id: @workflows.first.last.id, user_id: @user.id, organization_id: @organization.id)
  else
    pending
  end
end

Given("the organization enable_workflows option is enabled") do
  org = @organization.self_and_ancestors.reorder(depth: :asc).first
  org.enable_workflows = true
  org.save
end

Given("the user has a document with a workflow step") do
  wf_start_step = @workflows[1].detect {|wf| wf["step_type"] == "start_step"}
  @document = create(:document, organization_id: @organization.id, user_id: @user, workflow_step_id: wf_start_step.id )
  expect(@document.workflow_step_id).to have_content(wf_start_step.id)
end

Given("the user has completed a workflow step") do
  @document.workflow_step_id = WorkflowStep.find(@document.workflow_step_id).next_workflow_step_id
  @document.save
end

Then(/^the document should be on step_(\d)$/) do |int|
  expect(@document.workflow_step.slug).to have_content(@workflows.first[int.to_i-1].slug)
end