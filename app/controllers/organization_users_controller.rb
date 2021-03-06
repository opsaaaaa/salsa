class OrganizationUsersController < AdminUsersController
  skip_before_action :require_admin_permissions
  before_action :redirect_to_sub_org, only:[:index,:new,:show,:edit,:import_users,:edit_assignment]
  before_action :require_admin_permissions, only: [:archive,:restore]
  before_action :require_supervisor_permissions

  def index
    @organization = find_org_by_path(params[:slug])
    @user_ids = UserAssignment.where(organization_id: @organization.self_and_descendants.pluck(:id)).pluck(:user_id)

    super
  end

  def new
    @organization = find_org_by_path(params[:slug])

    super

  end

  def create
    @organization = find_org_by_path(params[:slug])

    super

    @user_assignment = UserAssignment.create(user_id:@user.id, organization_id:@organization.id ,role:"staff", cascades: true) if @user_saved
    flash[:notice] = "User successfully created."
  end

  def assign
    @organization = find_org_by_path(params[:slug])
    user_ids = UserAssignment.where(organization_id: @organizations.pluck(:id) ).pluck(:user_id)
    users = User.where(id: user_ids, archived: false)
    @user = users.find_by id: params[:user_assignment][:user_id]

    raise ActionController::RoutingError.new('Not Authorized') if @user.blank? && !has_role('admin')

    super
  end

  def edit_assignment
    @organization = find_org_by_path(params[:slug])

    super

    @user_assignments = @user_assignment.user.user_assignments.where(organization_id: @organization.self_and_descendants.pluck(:id))
    return redirect_to organization_users_path(org_path: params[:org_path]) if @user_assignment.blank?
  end

  def update_assignment
    @organization = find_org_by_path(params[:slug])

    super
  end

  def show
    @organization = find_org_by_path(params[:slug])
    user_ids = UserAssignment.where(organization_id: @organizations.pluck(:id) ).pluck(:user_id)
    users = User.where(id: user_ids, archived: false)
    @user = users.find_by id: params[:id]
    
    raise ActionController::RoutingError.new('Not Authorized') if @user.blank? && !has_role('admin')

    super
  end

  def edit
    @organization = find_org_by_path(params[:slug])
    user_ids = UserAssignment.where(organization_id: @organization&.self_and_descendants&.pluck(:id)).pluck(:user_id)
    users = User.where(id: user_ids, archived: false)
    @user = users.find_by id: params[:id].to_i

    raise ActionController::RoutingError.new('Not Authorized') if @user.blank?
  end

  def archive
    user_ids = UserAssignment.where(organization_id: find_org_by_path(params[:slug])).pluck(:user_id)
    users = User.where(id: user_ids)
    @user = users.find_by id: params["#{params[:controller].singularize}_id".to_sym].to_i
    @user.update(archived: true)
    flash[:notice] = "#{@user.email} has been archived"
    return redirect_to polymorphic_path([params[:controller]], org_path: params[:org_path])
  end

  def restore
    user_ids = UserAssignment.where(organization_id: find_org_by_path(params[:slug])).pluck(:user_id)
    users = User.where(id: user_ids)
    @user = users.find params["#{params[:controller].singularize}_id".to_sym].to_i
    @user.update(archived: false)
    flash[:notice] = "#{@user.email} has been activated"
    return redirect_to organization_user_edit_assignment_path(slug: params[:slug],id: @user.user_assignments.find_by(organization_id:find_org_by_path(params[:slug]).id).id)
  end

  def create_users
    org = @organizations.find_by(id: params[:users][:organization_id])
    org = find_org_by_path(params[:slug]) if org.blank?
    users_emails = params[:users][:emails].gsub(/ */,'').split(/(\r\n|\n|,)/).delete_if {|x| x.match(/\A(\r\n|\n|,|)\z/) }
    users_remote_ids = params[:users][:remote_user_ids].gsub(/ */,'').split(/(\r\n|\n|,)/).delete_if {|x| x.match(/\A(\r\n|\n|,|)\z/) }
    user_errors = Array.new
    users_created = 0
    user_errors.push "Add emails or remote user ids to import users" if params[:users][:emails].blank? && params[:users][:remote_user_ids].blank?
    users_remote_ids.each do |remote_user_id|
      user = User.import_or_create_by({user_assignment:{username: remote_user_id, organization_id:org.id}})
      user.errors.messages.each do |error|
        user_errors.push "Could not create user with remote user ID: '#{remote_user_id}' because: #{error[0]} #{error[1][0]}" if user.errors
      end
      next if !user.errors.empty?
      users_created +=1
    end
    users_emails.each do |user_email|
      user = User.import_or_create_by({user: {email: user_email},user_assignment:{organization_id:org.id}})
      user.errors.messages.each do |error|
        user_errors.push "Could not create user with email: '#{user_email}' because: #{error[0]} #{error[1][0]}" if user.errors
      end
      next if !user.errors.empty?
      users_created +=1
      UserMailer.welcome_email(user,org,component_allowed_liquid_variables(nil,user,org)).deliver_later
    end
    flash[:notice] = "#{users_created} Users Imported or created successfully" if users_created >= 1
    flash[:errors] = user_errors
    redirect_to organization_import_users_path(org_path: params[:org_path])
  end

  def import_users
    @organization = find_org_by_path(params[:slug])
  end

end
