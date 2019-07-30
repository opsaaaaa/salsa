class AdminDocumentsBaseController < AdminController
  def edit
    get_document params[:id]
    setup_edit_action @document
  end

  def versions
    get_document params[:id]
    if session[:admin_authorized] || has_role('admin')
      @document_versions = @document.versions.where(event: ["update","publish"])
    else
      @document_versions = @document.versions.where("object ~ ?",".*organization_id: #{get_org.id}.*").where(event: ["update","publish"])
    end
  end


  def revert_document
    get_document params[:id]
    @document = @document.versions.find(params[:version_id]).reify
    if @document.save
      flash[:notice] = "Document reverted to version #{params[:version_id]}"
    else
      flash[:error] = "Document failed to reverted to version #{params[:version_id]}"
    end
    redirect_back(fallback_location: organizations_path)
  end

  def update
    get_document params[:id]
    @periods = Period.where(organization_id: @document.organization&.parents&.pluck(:id).push(@document.organization&.id))

    # if the publish target changed, clear out the published at date
    if params[:document][:lms_course_id] && @document[:lms_course_id] != params[:document][:lms_course_id] || params[:document][:organization_id] && @document[:organization_id] != params[:document][:organization_id]
      @document[:lms_published_at] = nil
    end

    if @document.update document_params
      if params[:controller] == 'admin_documents'
        slug = ''
        if @document.organization
          slug = @document.organization.full_slug
        end

        redirect_to organization_path(slug: slug,org_path:params[:org_path])
      else
        flash[:notice] = "You have assigned a document to #{@user.email} on #{@wfs.slug}" if @user && @wfs
        redirect_to workflow_document_index_path(org_path: params[:org_path])
      end
    else
      flash[:error] = @document.errors.messages
      setup_edit_action @document
      get_users

      render 'edit'
    end
  end

  def delete
  end

  protected

  def setup_edit_action document
    organization_ids = document.organization_id
    
    if document.organization&.root_org_setting("inherit_workflows_from_parents")
      organization_ids = document.organization.root.self_and_descendants.pluck(:id)
    end

    @workflow_steps = WorkflowStep.where(organization_id: organization_ids).order(:name)
    get_periods
  end

  def get_document id=params[:id]
    @document = Document.find(id)
    unless has_role('designer', @document.organization) || has_role('supervisor', @document.organization)
      raise('Insufficent permissions for this document')
    end
  end

  def document_params
    if has_role("admin") || has_role("organization_admin")
      params.require(:document).permit(:name, :remote_identifier, :view_id, :lms_course_id, :workflow_step_id, :organization_id, :user_id, :period_id)
    elsif has_role("supervisor") || has_role("designer")
      params.require(:document).permit(:name, :remote_identifier, :view_id, :lms_course_id, :workflow_step_id, :user_id, :period_id)
    end
  end
end
