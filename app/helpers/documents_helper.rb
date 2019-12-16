module DocumentsHelper

  def edit_document_or_lms_course_path( condition: params[:lms_course_id] ,**path_args) 
    if condition
        path_args.delete(:id) 
        return lms_course_document_path( path_args )
    else
        path_args.delete(:lms_course_id)
        return edit_document_path( path_args )
    end
  end

  def existing_document?
    @has_existing_document ||= @existing_document && !@existing_document&.same_record_as?(@document)
  end

  def force_course_link?
    has_role("organization_admin") && params[:relink] == "true"
  end

  def link_document_course document
    if params[:lms_course_id] && document
      if !document.link_course( lms_course_id: params[:lms_course_id], force: force_course_link?, token: params[:document_token])
        flash[:error] = "Failed to link #{params[:lms_course_id]}"
        false
      else
        flash[:notice] = "Successfully linked the #{params[:lms_course_id]} course id to this document"
        true
      end
    end
  end

  def existing_document_within_organization? org: @organization, doc: @existing_document
    @is_existing_document_within_organization ||= @organization&.id == doc&.organization&.id
  end

  def lms_account_course_document_path
    org = get_org_by_lms_account_id
    return nil if org.blank?
    params.permit!
    lms_course_document_path( {org_path: org&.path || params[:org_path], lms_course_id: params[:lms_course_id]}.merge(params.except(:lms_course_id,:org_path, :action, :controller)))
  end

  def get_org_by_lms_account_id
    get_organization unless @organization
    get_lms_course( @organization.root_org_setting('lms_authentication_source') ) unless @lms_course
    @organization.root.self_and_descendants.find_by_lms_account_id(@lms_course['account_id'].to_s)
  end

  def get_course_name
    return @lms_course['name'] if @lms_courses
    return params[:name] || params[:lms_course_id] || "Unnamed"
  end

end