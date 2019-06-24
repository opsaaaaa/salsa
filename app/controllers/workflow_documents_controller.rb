class WorkflowDocumentsController < AdminDocumentsBaseController
  layout :set_layout
  
  #skip designer permissions from admin_controller
  skip_before_action :require_designer_permissions

  before_action :redirect_to_sub_org, only:[:index,:edit,:versions]
  before_action :check_organization_workflow_enabled
  before_action :set_paper_trail_whodunnit, only: [:revert_document]
  before_action :get_organizations_if_supervisor
  before_action :require_staff_permissions, only: [:index]
  before_action :require_supervisor_permissions, except: [:index,:assignments]
  before_action :require_management_permissions, only: [:assignments]

  def index
    @direct_assignments = current_user.assignments.pluck('role')
    @has_assignments = has_role("supervisor") || has_role("auditor") || @direct_assignments.include?('auditor') || @direct_assignments.include?('supervisor')

    org = get_org
    organization_ids = org.root.self_and_descendants.pluck(:id)
    user_assignment = current_user.user_assignments.find_by organization_id: org.id if current_user
    @workflow_steps = WorkflowStep.where(organization_id: organization_ids).order('name')
    @periods = Period.where(organization_id: organization_ids).order('name')
    @documents = Document.where(organization_id:org.self_and_descendants.pluck(:id))
      .where('documents.updated_at != documents.created_at')

    if params[:step_filter] && params[:step_filter] != ''
      wfs = @workflow_steps.find_by(slug: params[:step_filter])
      @user_documents = @documents.where(workflow_step_id: wfs&.id )
    else
      end_steps = @workflow_steps.where(organization_id: organization_ids).find_by(step_type: 'end_step')
      @user_documents = @documents.where.not(workflow_step_id: end_steps&.id )
        .where(user_id: current_user&.id)
    end

    if params[:period_filter] != nil && params[:period_filter] != ''
      @user_documents = @user_documents.where(period_id: params[:period_filter].to_i)
    end

    if params[:organization_filter] != nil && params[:organization_filter] != ''
      @user_documents = @user_documents.where(organization_id: params[:organization_filter].to_i)
    end

    @user_documents = @user_documents.order(updated_at: :desc)
      .page(params[:page])
      .per(params[:per])
  end

  def assignments
    @direct_assignments = current_user.assignments.pluck('role')
    @has_assignments = has_role("supervisor") || has_role("auditor") || @direct_assignments.include?('auditor') || @direct_assignments.include?('supervisor')

    org = get_org
    organization_ids = org.root.self_and_descendants.pluck(:id)
    user_assignment = current_user.user_assignments.find_by organization_id: org.id if current_user
    @workflow_steps = WorkflowStep.where(organization_id: organization_ids).order('name')
    @periods = Period.where(organization_id: organization_ids).order('name')
    @documents = Document
      .where(organization_id: organization_ids)
      .where('documents.updated_at != documents.created_at')
      .where.not(user_id: current_user.id)

    if params[:period_filter] != nil && params[:period_filter] != ''
      @documents = @documents.where(period_id: params[:period_filter].to_i)
    end

    if params[:organization_filter] != nil && params[:organization_filter] != ''
      @documents = @documents.where(organization_id: params[:organization_filter].to_i)
    end

    if params[:step_filter] && params[:step_filter] != ''
      wfs = @workflow_steps.where(organization_id: organization_ids).find_by(slug: params[:step_filter])
      @documents = @documents.where(workflow_step_id: wfs&.id )
    else
      end_steps = @workflow_steps.where(organization_id: organization_ids).find_by(step_type: 'end_step')
      @documents = @documents.where.not(workflow_step_id: end_steps&.id )
    end

    @documents = get_documents(current_user, @documents)
      .reorder(updated_at: :desc)
      .page(params[:page])
      .per(params[:per])
      
  end

  def update
    get_document params[:id]
    # if the publish target changed, clear out the published at date
    if params[:document][:workflow_step_id] != @document.workflow_step_id && !params[:document][:workflow_step_id].blank? && !params[:document][:user_id].blank?
      @wfs = WorkflowStep.find(params[:document][:workflow_step_id])
      if @wfs.step_type == "start_step"
        @user = User.find_by(id: params[:document][:user_id], archived: false)
        WorkflowMailer.welcome_email(@document, @user, @organization, @wfs.slug, component_allowed_liquid_variables(@document.workflow_step,User.find(params[:document][:user_id]),@organization, @document)).deliver_later
      end
    end

    # if the publish target changed, clear out the published at date
    if params[:document][:lms_course_id] && @document[:lms_course_id] != params[:document][:lms_course_id] || params[:document][:organization_id] && @document[:organization_id] != params[:document][:organization_id]
      @document[:lms_published_at] = nil
    end

    if @document.update document_params
      flash[:notice] = "You have assigned a document to #{@user.email} on #{@wfs.slug}" if @user && @wfs
      redirect_to workflow_document_index_path(org_path: params[:org_path])
    else
      flash[:error] = @document.errors.messages

      render 'edit', layout: 'admin'
    end
    super
  end

  private

  def get_users
    @users = UserAssignment.where(organization_id:@document.organization.descendants.pluck(:id) + [@document.organization.id]).map(&:user)
    @users.push @document.user if @document.user
  end

  def document_params
    params.require(:document).permit(:name, :lms_course_id, :workflow_step_id, :user_id, :period_id)
  end

  def get_documents user, documents
    document_ids = []
    documents.each_with_index do |document, index|
      if document.assigned_to? user
        document_ids.push document.id
      end
    end
    return Document.where(id: document_ids)
  end

  def get_organizations_if_supervisor
    if has_role('supervisor')
      get_organizations
      @organization = get_org
    end
  end

  def set_layout
    return 'workflow'
  end
end
