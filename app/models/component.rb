class Component < ApplicationRecord
  has_paper_trail
  attr_accessor :user_role #This is an attribute which controller will use to turn on/off some validation logic depending on the current user

  has_many :workflow_steps
  belongs_to :organization

  validate :format_is_valid
  validate :slug_is_valid

  validates_uniqueness_of :slug, :scope => :organization_id
  validates_format_of :slug, :with => /\A[a-z0-9\-\_\.]+\Z/, message: "must only contain lowercase letters, numbers, periods(.), hyphens(-) and underscores(_) "
  validates :role, inclusion: {in: UserAssignment.roles.values, message: "you cant create that role", :allow_blank => true}

  def is_admin
    if @user_role == "admin"
      return true
    else
      return false
    end
  end

  def format_is_valid
    if Component.valid_formats(is_admin).include?(format)
      return true
    else
      errors.add(:format, 'Invalid')
    end
  end

  def slug_is_valid
    if valid_slugs.include?(slug) || is_admin
      return true
    else
      errors.add(:slug, 'Invalid')
    end
  end

  def self.valid_formats(has_admin_role)
    if has_admin_role
      ['html','liquid','erb','haml']
    else
      ['html','liquid']
    end
  end

  def valid_slugs
    organization = self.organization
    slugs = ['salsa', 'section_nav', 'control_panel', 'footer', 'dynamic_content_1', 'dynamic_content_2', 'dynamic_content_3', 'user_welcome_email']
    if organization.root_org_setting("enable_workflows")
      wfsteps = WorkflowStep.where(organization_id: organization.organization_ids+[organization.id])
      slugs += wfsteps.map(&:slug).map! {|x| x + "_mailer" }
      slugs.push "workflow_welcome_email"
    end
    slugs.delete_if { |a| organization.components.map(&:slug).include?(a) }
    if !self.new_record?
      slugs.push self.slug_was
    end
    return slugs
  end


  def to_param
    slug
  end
end
