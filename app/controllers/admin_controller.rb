class AdminController < ApplicationController
  before_action :redirect_to_sub_org, only:[:landing]
  before_action :require_designer_permissions, except: [
    :landing,
    :unassigned_user,
    :request_access,
    :login,
    :logout,
    :user_activation,
    :create_user,
    :authenticate,
    :canvas_accounts,
    :canvas_courses,
    :canvas_accounts_sync,
    :canvas_courses_sync,
    :workflows
  ]
  before_action :require_organization_admin_permissions, only: [
    :canvas_accounts,
    :canvas_courses,
    :canvas_accounts_sync,
    :canvas_courses_sync

  ]
  before_action :get_organizations, only: [
      :search,
      :canvas_accounts,
      :canvas_courses
  ]
  force_ssl only:[:canvas_courses, :canvas_accounts,:canvas_courses,:canvas_accounts_sync]

  def landing
    if current_user&.archived
      return redirect_to admin_unassigned_user_path
    end
    if has_role 'designer' or has_role 'supervisor'
      redirect_to organizations_path(org_path: get_org&.path), notice: flash[:notice]
    elsif has_role 'auditor'
      redirect_to admin_auditor_reports_path, notice: flash[:notice]
    elsif ( has_role('staff', assignment_org = get_user_assignment_org(session[:authenticated_user],'staff')) || has_role('approver', assignment_org = get_user_assignment_org(session[:authenticated_user],'approver')) || has_role('supervisor', assignment_org = get_user_assignment_org(session[:authenticated_user],'supervisor')) ) && assignment_org&.root_org_setting('enable_workflows') == true
      redirect_to workflow_document_index_path(org_path: assignment_org.path), notice: flash[:notice]
    else
      redirect_or_error
    end
  end

  def login
    @organization = find_org_by_path params[:slug]
    if @organization&.root_org_setting("enable_shibboleth")
      return redirect_to new_user_session_path(org_path: params[:org_path])
    end
  	if @organization and @organization.setting("lms_authentication_source") != nil
  		redirect_to oauth2_login_path
	  else
  		render action: :login, layout: false
  	end
  end

  def authenticate

    # allow using the login form for the admin password if it is set
    if APP_CONFIG['admin_password']
        if params[:user][:email] == 'admin@' + (params[:slug] || get_org_slug)
          session[:admin_authorized] = params[:user][:password] == APP_CONFIG['admin_password']

          return redirect_to admin_path
        end
    end

  	@organization = find_org_by_path params[:slug]

    unless params[:user][:email] && params[:user][:password]
        flash[:error] = 'Missing email or password'
        return render action: :login, layout: false
    end

    user = User.where(archived: false,email: params[:user][:email]).first

    if !user
        flash[:error] = 'No account matches the email provided'
    elsif !user.password_digest# && user.activated
        flash[:error] = 'Your account is not active yet'
    elsif !user.authenticate(params[:user][:password])
        flash[:error] = 'Invalid email or password'
    end

    if !flash[:error].blank?
      return render action: :login, layout: false
    end

    session[:authenticated_user] = user.id
    redirect_to admin_path, notice: 'Logged in successfully'
  end


  def unassigned_user
    render(:layout => "layouts/workflow")
  end

  def request_access
    user = User.find_by(id: session[:authenticated_user])
    org = get_org
    UserMailer.new_unassigned_user_email(user, org, {"user_name" => "#{user&.name}","user_email" => "#{user&.email}", "organization_name" => "#{org&.name}", "archived_users_url" => "#{org.full_slug}/admin/organization/#{org.full_slug}/users?show_archived=true"}).deliver_later if !session[:access_requested]
    session[:access_requested] = true
    render(:layout => "layouts/workflow")
  end

  def canvas_accounts
    org_slug = get_org_slug
    @org = Organization.find_by slug: org_slug

    org_meta = OrganizationMeta.where(
      root_id: @org['id'],
      key: [
        'id',
        'name',
        'parent_account_id',
        'root_account_id',
        'sis_account_id',
        'workflow_state'
      ]
    )

    @org_meta = PivotTable::Grid.new do |g|
      g.source_data = org_meta
      g.column_name = :key
      g.row_name = :lms_organization_id
    end

    @org_meta.build

    render 'admin/canvas/accounts'
  end

  def canvas_courses
    @org = Organization.find_by slug: get_org_slug
    per_page = 10
    per_page = params[:per] if params[:per]
    if params[:show_course_meta]
      @document_meta = DocumentMeta.where(root_organization_id: @org.id).reorder(created_at: :desc).page(params[:page]).per(per_page)
    end

    @queued = Que.execute("select run_at, job_id, error_count, last_error, queue from que_jobs where job_class = 'CanvasSyncCourseMeta'")
    @queued_count = @queued.count

    render 'admin/canvas/courses'
  end

  def canvas_accounts_sync
    @canvas_access_token = params[:canvas_token]

    org_slug = get_org_slug

    @org = Organization.find_by slug: org_slug

    if @org
      @canvas_endpoint = @org.setting('lms_authentication_source')

      @canvas_client = Canvas::API.new(:host => @canvas_endpoint, :token => @canvas_access_token)

      if @canvas_client
        canvas_root_accounts = @canvas_client.get("/api/v1/accounts")

        canvas_root_accounts.each do |canvas_root_account|
          sync_canvas_accounts canvas_root_account, @org[:id]
        end
      else
        false
      end
    else
      false
    end

    redirect_to canvas_accounts_path
  end

  def canvas_courses_sync
    @canvas_access_token = params[:canvas_token]
    accounts = params[:account_ids]
    org_slug = get_org_slug

    CanvasHelper.courses_sync_as_job org_slug, @canvas_access_token, accounts

    redirect_to canvas_courses_path
  end

  def sync_canvas_accounts account, org_id = nil
    # store each piece of data into the organization meta model
    account.each do |key, value|
      meta = OrganizationMeta.find_or_initialize_by organization_id: org_id,
        key: key,
        root_id: @org[:id],
        lms_organization_id: account['id'].to_s

      meta[:value] = value.to_s

      meta.save
    end

    @child_accounts = @canvas_client.get("/api/v1/accounts/#{account['id']}/sub_accounts?per_page=50")

    @child_accounts.next_page! while @child_accounts.more?

    @child_accounts.each do |child_account|
      sync_canvas_accounts child_account
    end
  end

  def logout
    notice = flash[:notice]
    reset_session
    flash[:notice] = notice
    redirect_to root_path;
  end

  def create_user
    user = User.find_by(activation_digest: (params[:id]))
    if user
      user.update user_params
      user.activate
      ua = UserAssignment.find_or_initialize_by(user_id: user.id, organization_id:get_org.id )
      ua.username = params[:user_remote_id]
      ua.role = "staff" if ua.role.blank?
      ua.save
      flash[:notice] = "Account Successfully Activated"
      redirect_to admin_path
    else
      return render :file => "public/410.html", :status => :gone, :layout => false
    end
  end

  def user_activation
    user = User.find_by(activation_digest: (params[:id]))
    if get_org.root_org_setting("enable_shibboleth")
      return redirect_to new_user_session_path
    elsif user
  		render action: :user_activation, layout: false
    else
      return render :file => "public/410.html", :status => :gone, :layout => false
    end
  end

  def search page=params[:page], per=25
    @organization = find_org_by_path params[:slug]
    search_document_text = ''
    user_name = user_email = user_id = user_remote_id = nil

    user_email = params[:q] if params[:search_user_email]
    user_id = params[:q].to_i if params[:search_user_id]
    user_name = "%#{params[:q]}%" if params[:search_user_name]
    user_remote_id = params[:q] if params[:search_connected_account_id]

    user_ids = User.where("email = ? OR id = ? OR name ~* ? ", user_email, user_id, user_name).pluck(:id)
    user_ids += UserAssignment.where("lower(username) = ? ", user_remote_id.to_s.downcase).pluck(:user_id) if user_remote_id

    sql = [
      "organization_id IN (:org_ids) AND (
      lms_course_id like :search_any OR 
      name like :search_any OR 
      edit_id like :search_start OR 
      view_id like :search_start OR 
      template_id like :search_start OR 
      remote_identifier like :search_start"
    ]
    param = {search_start: "#{params[:q]}%", search_any: "%#{params[:q]}%"}    
    
    if @organization.root_org_setting("document_search_includes_sub_organizations")
      param[:org_ids] = @organization.self_and_descendants.pluck(:id)
    else 
      param[:org_ids] = [@organization.id]
    end

    if user_ids.present?
      sql << "OR user_id IN (:user_ids)"
      param[:user_ids] = user_ids
    end

    if params[:search_document_text]
      sql << "OR payload like :search_any"
    end

      sql << ")"
    @documents = Document.where(sql.join(' '), param).page(page).per(per)
  end


  def canvas_connection_information
    redirect_port = ':' + request.env['SERVER_PORT'] unless ['80', '443'].include?(request.env['SERVER_PORT'])

    # custom authentication source, use the keys from the DB
    if @organization && @organization.setting('lms_authentication_source') != nil
      @oauth_endpoint = @organization.setting('lms_authentication_source')
      @lms_client_id = @organization[:lms_authentication_id] unless @organization[:lms_authentication_id] == ''
      @lms_secret = @organization[:lms_authentication_key] unless @organization[:lms_authentication_key] == ''
    end

    if canvas_access_token && canvas_access_token != ''
      @lms_client = Canvas::API.new(:host => @oauth_endpoint, :token => canvas_access_token)

      # if this throws an error, there is something wrong with the token
      begin
        @lms_user = @lms_client.get("/api/v1/users/self/profile") if @lms_client.token
      rescue
        # clear the session and start over
        redirect_to oauth2_logout_path
      end
    elsif @lms_client_id
      @lms_client = Canvas::API.new(:host => @oauth_endpoint, :client_id => @lms_client_id, :secret => @lms_secret)

      @redirect_url = "#{@lms_client.oauth_url(@callback_url)}"
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end

end
