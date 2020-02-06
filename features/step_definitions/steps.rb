

When /^S3 uploads are stubbed out$/ do
  Aws.config[:s3] = {
    stub_responses: {
      list_buckets: { buckets: [{name: ENV["AWS_BUCKET"] }] },
      get_object: { body: 'data' }
    }
  }
end

Given(/^there is a (\w+)$/) do |class_name|
  case class_name
  when /workflow/
    recordA = create(:workflow_step, slug: "step_5", step_type: "end_step", organization_id: @organization.id)
    componentA = recordA.component
    componentA.user_role = "admin"
    componentA.role = nil
    componentA.save
    recordB = create(:workflow_step, slug: "step_4", next_workflow_step_id:recordA.id, organization_id: @organization.id)
    componentB = recordB.component
    componentA.user_role = "admin"
    componentB.role = "approver"
    componentB.save
    recordC = create(:workflow_step, slug: "step_3", next_workflow_step_id: recordB.id, organization_id: @organization.id)
    componentC = recordC.component
    componentA.user_role = "admin"
    componentC.role = "supervisor"
    componentC.save
    recordD = create(:workflow_step, slug: "step_2", next_workflow_step_id: recordC.id, organization_id: @organization.id)
    componentD = recordD.component
    componentA.user_role = "admin"
    componentD.role = "supervisor"
    componentD.save
    recordE = create(:workflow_step, slug: "step_1", next_workflow_step_id: recordD.id, step_type: "start_step", organization_id: @organization.id)
    componentE = recordE.component
    componentA.user_role = "admin"
    componentE.role = "staff"
    componentE.save
    @workflows = WorkflowStep.workflows(@organization.id)
  when /document/ || /canvas_document/
    record = create(class_name, organization_id: @organization.id)
    instance_variable_set("@#{class_name}",record)
  when /organization/
    @organization = FactoryBot.create(:organization)
  else
    record = create(class_name)
    instance_variable_set("@#{class_name}",record)
  end
end

Given(/^I save the page$/) do
  save_page
end

Given("debugger") do
  debugger
end

Given("the reports are generated") do
    params = {
      "account_filter" => "FL17",
      "controller" => "admin",
      "action" => "canvas"
    }
  report = create(:report_archive, organization_id: @organization.id, report_filters: params, generating_at: Time.now)
  ReportHelper.generate_report(@organization.slug, "FL17", params, report.id)
  sleep 1
  visit "/admin/reports"
  expect(page).to have_content("FL17")
end

Then("I should receive the report file") do
  filename = "#{@organization.slug}"
  page.response_headers['Content-Disposition'].to_s.include?(/filename=\"#{filename}_.*\.zip\"/.to_s)

end

Then("the Report zip file should have documents in it") do
  a = page.driver.response.body.gsub(/[^0-9a-z._]/i, '')
  expect(a).to have_content(".html")
  expect(a).to have_content(".css")
end

Then("I should not be able to edit the employee section") do
  puts "##### Cant test beyond this point before we have components and permissions setup #####"
  pending
end

Then("I should see a saved document") do
  @document
end
