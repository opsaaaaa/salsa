class User < ApplicationRecord
  include Populate
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
  
  def self.get_lti_user(&block)
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

  def self.lazy_params(params = {})
    {
      archived: false,
      email: "#{Faker::Name.first_name}@example.com",
      name: "New User",
      password: "#{rand(36**40).to_s(36)}"
    }.merge(params)
  end

  def self.lazy_create(user_params = {},role_params = {})
    user = User.create lazy_params(user_params)
    user.add_role UserAssignment.lazy_params(role_params) if role_params.present?
    user
  end

  def add_role(params)
    return nil if params[:organization_id].blank?
    UserAssignment.create UserAssignment.lazy_params({user_id: self.id}.merge(params))
  end

  def self.import_or_create_by get_params, set_params = nil
    get_params = {user: get_params, user_assignment: {}} if get_params[:user].blank? && get_params[:user_assignment].blank?
    set_params = get_params if set_params.blank?
    set_params[:user] = {} if set_params[:user].blank?
    set_params[:user_assignment] = {} if set_params[:user_assignment].blank?
    ua = nil
    if get_params[:user_assignment][:username].present?
      ua = UserAssignment.find_by("lower(username) = ? ", get_params[:user_assignment][:username].to_s.downcase)
      set_params[:user] = {email: "#{get_params[:user_assignment][:username]}@example.com"}.merge(set_params[:user])
    end
    user = User.find_by get_params[:user] if get_params[:user].present?
    user = ua.user if ua
    user = User.new() if user.blank?
    user.archived = false
    user.populate lazy_params(set_params[:user])
    user.add_org set_params[:user_assignment][:organization_id], set_params[:user_assignment] 
    user
  end

  def add_org org_id, ua_params = {}
    ua_params = {organization_id: org_id}.merge(ua_params)
    ua = self.user_assignments.find_by(ua_params) 
    self.add_role ua_params if ua.blank?
    return self
  end

end
