include CollectiveIdea::Acts::NestedSet

class OrganizationsController < AdminController
  before_action :redirect_to_sub_org, only:[:index,:start_workflow_form,:new,:show,:edit]
  before_action :require_organization_admin_permissions, except: [:show, :index, :start_workflow_form, :start_workflow]
  before_action :require_supervisor_permissions, only: [:start_workflow_form, :start_workflow]
  before_action :require_designer_permissions, only: [
      :show,
      :index
  ]
  before_action :get_organizations
  layout 'admin'
  def index
    get_documents
    @roots = @organizations.roots

    redirectOrg = nil
    if @roots.count == 1
      redirectOrg = @roots[0]
    elsif @organizations.size == 1
      redirectOrg = @organizations[0]
    end

    if redirectOrg
      redirect_to organization_path(slug: full_org_path(redirectOrg), org_path: params[:org_path])
    end
  end

  def new
    @export_types = Organization.export_types
    @organization = Organization.new
  end

  def orphaned_documents
    get_documents
  end

  def documents
    if params[:document_ids]
      if params[:organization][:id] != ''
        org_id = params[:organization][:id]
      else
        org_id = nil
      end

      Document.where(:id => params[:document_ids]).update_all(["organization_id=?", org_id])
    end

    return redirect_to organization_path(slug: Organization.find(org_id).slug, org_path: params[:org_path]) if org_id
    redirect_to organizations_path(org_path: params[:org_path])
  end

  def show
    get_documents params[:slug]
    get_periods
  end

  def edit
    @export_types = Organization.export_types
    get_documents params[:slug]

    @workflow_steps = WorkflowStep.where(organization_id: @organization.organization_ids+[@organization.id])
    @organization.default_account_filter = '{"account_filter":""}' unless @organization.default_account_filter
    @organization.default_account_filter = '{"account_filter":""}' if @organization.default_account_filter == ''

    @organization.default_account_filter = @organization.default_account_filter.to_json if @organization.default_account_filter.class == Hash
  end

  # commit actions
  def create
    @export_types = Organization.export_types
    @organization = Organization.new 
    @organization.assign_attributes organization_params

    respond_to do |format|
      if !@organization.errors.any? and @organization.save
        format.html { redirect_to organization_path(full_org_path(@organization), org_path: params[:org_path]), notice: 'Organization was successfully created.' }
        format.json { render :show, status: :created }
      else
        format.html { render :new }
        format.json { render json: @organization.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @export_types = Organization.export_types
    @organization = find_org_by_path params[:slug]

    if has_role('admin') && params['organization']['default_account_filter'] != nil
      if params['organization']['default_account_filter'] != ''
        params['organization']['default_account_filter'] = JSON.parse(params['organization']['default_account_filter'])
      else
        params['organization']['default_account_filter'] = ''
      end
    end


    respond_to do |format|
      if @organization&.update organization_params
        format.html { redirect_to organization_path(slug: full_org_path(@organization), org_path: params[:org_path]), notice: 'Organization was successfully updated.' }
        format.json { render :show, status: :created }
      else
        get_organizations
        @workflow_steps = WorkflowStep.where(organization_id: @organization.organization_ids+[@organization.id])
        format.html { render :edit }
        format.json { render json: @organization.errors, status: :unprocessable_entity }
      end
    end
  end

  def delete
    @organization = find_org_by_path params[:slug]
    @organization.delete

    redirect_to organizations_path( org_path: params[:org_path])
  end

  def import

  end

  def start_workflow_form
    @organization = @organizations.all.select{ |o| o.full_slug == params[:slug] }.first
    @workflow_steps = WorkflowStep.where(organization_id: @organization.organization_ids+[@organization.id], step_type: "start_step")
    user_ids = @organization.user_assignments.pluck(:user_id)
    @users = User.find_by(id: user_ids)
    @periods = Period.where(organization_id: @organization.organization_ids+[@organization.id])
  end

  def start_workflow
    params.require("Start Workflow").permit(:document_name,:starting_workflow_step_id,:period_id,:start_for_sub_organizations)
    start_workflow_params = params["Start Workflow"]
    if start_workflow_params[:period_id] == "" || start_workflow_params[:starting_workflow_step_id] == "" || start_workflow_params[:document_name] == ""
      flash[:error] = "all fields must be filled"
      return redirect_back(fallback_location: start_workflow_form_path)
    end
    organization = find_org_by_path(params[:slug])
    if start_workflow_params[:start_for_sub_organizations]
      organizations = organization.descendants + [organization]
    else
      organizations = [organization]
    end
    counter = 0
    organizations.each do |org|
      user_ids = org.user_assignments.where(role: ["supervisor","staff"]).pluck(:user_id)
      users = User.where(id: user_ids, archived: false)
      users.each do |user|
        next if user.documents.map(&:period_id).include?(start_workflow_params[:period_id].to_i)
        document = Document.create(workflow_step_id: start_workflow_params[:starting_workflow_step_id].to_i, organization_id: org.id, period_id: start_workflow_params[:period_id].to_i, user_id: user.id)
        document.update(name: start_workflow_params[:document_name] )
        WorkflowMailer.welcome_email(document, user, org, document.workflow_step.slug,component_allowed_liquid_variables(document.workflow_step.slug, user, org, document )).deliver_later
        counter +=1
      end
    end

    flash[:notice] = "successfully started workflow for #{counter} users for the #{Period.find(start_workflow_params[:period_id].to_i).name} period"
    return redirect_to start_workflow_form_path( org_path: params[:org_path])
  end


  private

  def get_documents path=params[:slug], page=params[:page], per=25, key=params[:key]
    if key == 'abandoned'
      operation = '=';
    else
      operation = '!='
    end

    if path
      @organization = find_org_by_path path
    end

    if @organization
      organization_ids = @organization.id
      documents = Document.where("documents.organization_id IN (?) AND documents.updated_at #{operation} documents.created_at", organization_ids)
    else
      documents = Document.where("documents.organization_id IS NULL AND documents.updated_at #{operation} documents.created_at")
    end

    @documents = documents.order(updated_at: :desc, created_at: :desc).page(page).per(per)
  end

  def organization_params
    org_params = params.require(:organization)

    if !has_role 'admin'
      if org_params[:parent_id] == '' or org_params[:parent_id] == nil
        if @organization.parent_id != nil or @organization.new_record?
          @organization.errors.add('parent_id', ' is required')
        end
      else
        if !@organization.new_record? and @organization.parent_id == nil
          @organization.errors.add('parent_id', ' cannot be changed for top level organizations')
        end

        if org_params[:parent_id].to_i != @organization.parent_id
          if !@organizations.map(&:id).include?(org_params[:parent_id].to_i)
            @organization.errors.add('parent_id', ' is invalid.')
          end
        end
      end
    end

    if org_params[:parent_id] == ''
      if org_params[:slug].start_with?('/')
        @organization.errors.add('slug', ' must not start with `/` for top level organizations.')
      end
    else
      blocked_slugs = ['/admin', '/salsa', '/lms', '/oauth2', '/lti', '/login', '/document', '/documents', '/workflow']
      if !org_params[:slug].start_with?('/')
        @organization.errors.add('slug', ' must start with `/` for sub-organizations.')
      elsif blocked_slugs.include?(org_params[:slug].downcase)
        @organization.errors.add('slug', ' is a reserved path. Choose another slug.')
      end
    end

    if has_role 'organization_admin'
      org_params.permit(:name, :export_type, :slug, :period_meta_key, :enable_workflows, :inherit_workflows_from_parents, :parent_id, :lms_authentication_source, :lms_authentication_id, :lms_authentication_key, :lms_info_slug, :lms_account_id, :home_page_redirect, :skip_lms_publish, :enable_shibboleth, :idp_sso_target_url, :idp_slo_target_url, :idp_entity_id, :idp_cert, :idp_cert_fingerprint, :idp_cert_fingerprint_algorithm, :authn_context, :enable_anonymous_actions, :track_meta_info_from_document, :disable_document_view,
      :force_https, :enable_workflow_report, :reports_include_lms, :default_account_filter, default_account_filter: [:account_filter])
    end
  end
end
