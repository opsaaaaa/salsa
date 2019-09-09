include ApplicationHelper
class WorkflowMailer < ApplicationMailer
  helper :application
  def step_email document, allowed_variables
    user = document.user
    organization = document.organization
    orgs = organization.self_and_ancestors
    workflow_step = document.workflow_step

    @component = Component.find_by(organization_id: orgs.pluck(:id), slug: workflow_step.slug) if workflow_step
    @mail_component = Component.find_by(organization_id: orgs.pluck(:id), category: "mailer", slug: "#{workflow_step&.slug}_email", format: "liquid")
    if @mail_component
      @template = Liquid::Template.parse(@mail_component.layout)
      @subject = Liquid::Template.parse(@mail_component.subject).render(allowed_variables).html_safe
      @step_email = @template.render(allowed_variables).html_safe

      role = @component.role if @component
      role = @mail_component.role if @mail_component.role && @mail_component.role != ''

      if role == "supervisor"
        users = document.assignees
        # send email to all users together so they can coordinate if desired
        send_email(to: users.pluck(:email), subject: @subject)
        user = nil
      elsif role == "approver"
        user_ids = document.approvers_that_have_not_signed.pluck :id
        user = document.closest_users_with_role("approver", user_ids).where(id:user_ids).first
      end
      send_email(to: user&.email, subject: @subject) if !user.blank?
    end
  end

  def welcome_email document, user, organization, step_slug, allowed_variables
    orgs = organization.parents.push(organization)
    @mail_component = Component.find_by(organization_id: orgs.pluck(:id),category: "mailer", slug: "#{step_slug}_email", format: "liquid")
    if @mail_component
      @template = Liquid::Template.parse(@mail_component.layout)
      @welcome_email = @template.render(allowed_variables).html_safe
      @subject = Liquid::Template.parse(@mail_component.subject).render(allowed_variables).html_safe
      send_email(to: user.email, subject: @subject)
    end
  end
end
