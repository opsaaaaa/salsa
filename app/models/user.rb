class User < ApplicationRecord
  devise :saml_authenticatable

  before_save { self.email = email.downcase }
  validates :name, presence: true, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 50 }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }
  # validates :password, presence: true, length: { minimum: 8 }

  has_many :user_assignments
  has_many :documents
  has_many :assignments, foreign_key: "user_id"
  has_many :assignees, class_name: 'Assignment', foreign_key: :team_member_id
  has_many :managers, through: :assignees, source: :user
  has_many :team_members, :class_name => 'User', through: :assignments, source: "team_member"
  has_many :organizations, through: :user_assignments

  has_secure_password validations: false
  validates_presence_of :password, on: :create

  has_many :user_assignments

  def self.saml_resource_locator(model, saml_response, auth_value)
    user = UserAssignment.find_by("lower(username) = ?", auth_value.to_s.downcase)&.user
    user = User.find_by(email: saml_response.attribute_value_by_resource_key("email")) if user.blank?
    return user
  end

  def self.saml_update_resource_hook(user, saml_response, auth_value)
    saml_response.attributes.resource_keys.each do |key|
      case key
      when /(first_name|last_name)/
        user.send "name=", "#{saml_response.attribute_value_by_resource_key("first_name")} #{saml_response.attribute_value_by_resource_key("last_name")}"
      when /id/
        org = Organization.find_by(slug: URI.parse(saml_response.raw_response.destination).host)
        user.send "password=", SecureRandom.urlsafe_base64 if user.password_digest.blank?
        user.save! if user.new_record?
        ua = user.user_assignments.where(organization_id: org.descendants.pluck(:id))
        if ua.blank?
          new_ua = UserAssignment.find_or_initialize_by(user_id: user.id, organization_id: org.id )
          new_ua.username = saml_response.attribute_value_by_resource_key(key)
          new_ua.role = "staff" if new_ua.new_record?
          new_ua.cascades = true if new_ua.new_record?
          user.archived = true if new_ua.new_record? && user.user_assignments.blank?
          user.activated = true if !new_ua.new_record?
          if new_ua.new_record? || new_ua.username.blank?

            new_ua.save
          end
        end
        ua.each do |ua|
          ua.username = saml_response.attribute_value_by_resource_key(key)
          ua.save
        end

      else
        user.send "#{key}=", saml_response.attribute_value_by_resource_key(key)
      end
    end

    user.send "password=", SecureRandom.urlsafe_base64 if user.password_digest.blank?

    if (Devise.saml_use_subject)
      user.send "#{Devise.saml_default_user_key}=", auth_value
    end

    user.save!
  end

  # def self.authenticate_with_saml(saml_response, relay_state)
  #   super
  # end

  def has_global_role?
    self.user_assignments.find_by(organization_id: nil).present?
  end

  def activate
    if !self.activated
      self.activation_digest = nil
      self.activated_at = DateTime.now
      self.activated = true
      self.save
    end
  end
  
  def self.get_lti_user
    assignment = UserAssignment.find_by_lti_info do
      yield
    end
    return nil unless assignment.present?
    return nil if assignment.user.has_global_role?
    assignment.user
  end

  def self.create_lti_user
    user_params = yield[:user]
    user = User.new user_params
    user.save
    raise user.to_yaml
    assignment_params = yield[:user_assignment]
    assignment = User.new yield[:user]
  end

  def self.lazy_create
    params = yield
    params = {user: params, user_assignment: nil} if params.present? && params[:user].blank?
    params[:user_assignment] = {} if params[:user_assignment].blank?
    # test_user = User.find_by(email: params[:user][:email])
    # test_user.delete if test_user
    # default params for new user
    user_params = {
      archived: false,
      email: "#{Faker::Name.first_name}@example.com",
      name: "New User",
      password: "#{rand(36**40).to_s(36)}"
    }
    # mege in given params overriding the defaults when defined 
    user_params = user_params.merge(params[:user])
    user = User.create user_params
    ua_params = {user_id: user.id}.merge(params[:user_assignment])
    # lazy create user_assignment
    ua = UserAssignment.lazy_create {ua_params}
    user
  end

  def self.import_by(val)
    raise val.inspect

    user = User.find_by(email: user_email)
    if user.blank?
    end
    
    User.find_by

    

    self.lazy_create

    user_params = yield[:user]
    ua_params = yield[:user_assignment]
    users_remote_ids.each do |remote_user_id|
      ua = UserAssignment.where("lower(username) = ? ", remote_user_id.to_s.downcase).first
      user = ua&.user
      user = User.new() if user.blank?
      user.password = "#{rand(36**40).to_s(36)}" if !user&.password
      user.name = "New User" if !user&.name
      user.email = "#{remote_user_id}@example.com" if !user&.email
      user.archived = false
      user.activated = false if ua.blank?
      user.save
      ua = UserAssignment.create(username: remote_user_id, role:"staff",user_id: user.id, organization_id: org.id, cascades: true) if ua&.organization_id != org&.id
      user.errors.messages.each do |error|
        user_errors.push "Could not create user with remote user ID: '#{ua.username}' because: #{error[0]} #{error[1][0]}" if user.errors
      end
      next if !user.errors.empty?
      users_created +=1
    end
    users_emails.each do |user_email|
      user = User.find_or_initialize_by(email: user_email)
      user.password = "#{rand(36**40).to_s(36)}" if !user&.password
      user.name = "New User" if !user&.name
      user.archived = false
      user.activated = false
      user_activation_token user
      user.save
      UserAssignment.create(role:"staff",user_id:user.id,organization_id:org.id,cascades:true) if user
      user.errors.messages.each do |error|
        user_errors.push "Could not create user with email: '#{user.email}' because: #{error[0]} #{error[1][0]}" if user.errors
      end
      next if !user.errors.empty?
      users_created +=1
      UserMailer.welcome_email(user,org,component_allowed_liquid_variables(nil,user,org)).deliver_later
    end
    # users_remote_ids.each do |remote_user_id|
    user = User.find_or_initialize_by(email: user_email)
    user = User.new user_params if user.blank?

    ua = UserAssignment.where("lower(username) = ? ", ua_params[:remote_user_id].to_s.downcase).first
    user = ua&.user

end
