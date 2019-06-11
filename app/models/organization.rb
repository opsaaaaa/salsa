class Organization < ApplicationRecord
  acts_as_nested_set

  has_many :documents
  has_many :components
  has_many :periods
  has_many :user_assignments
  has_many :users, through: :user_assignments
  has_many :workflow_steps


  default_scope { order('lft, rgt') }
  validates :slug, presence: true
  validates_uniqueness_of :slug, :scope => :parent_id
  validates :slug, exclusion: { in: %w(status), message: "%{value} is reserved." }
  validates :name, presence: true

  def self.export_types
    ["default","Program Outcomes"]
  end
  validates :export_type, :inclusion=> { :in => self.export_types }

  def full_slug
    if self.slug.start_with?("/")
      slugs = self.parents.reverse.map(&:slug) + [self.slug.gsub(/\//,'')]
      return slugs.join('/').gsub(/\/\//,'/')
    else
      return self.slug
    end
  end

  def path
    if self.slug.start_with?("/")
      slugs = self.parents.reverse.map(&:slug) + [self.slug.gsub(/\//,'')]
      slugs[1..-1].join('/').gsub(/\/\//,'/').gsub(/^\//,'')
    end
  end

  def parents
    parents = []
    parent = self.parent
    while parent != nil do
      parents.push parent
      parent = parent.parent
    end
    return parents
  end

  def organization_ids
    org_ids = [self.id]
    if self.root_org_setting("inherit_workflows_from_parents")
      org_ids = self.parents.map{|x| x[:id]}
    end
    return org_ids
  end

  def full_org_path
    if self.depth > 0 and self.slug.start_with?('/')
      org_slug = self.self_and_ancestors.pluck(:slug).join ''
    else
      org_slug = self.slug
    end

    org_slug
  end

  # force null save so setting can cascade up the tree (most settings should probably be this way)
  def lms_authentication_source=(val)
    super(val == "" ? nil : val)
  end

  def setting(setting)
    value = nil
    org = self.self_and_ancestors.where.not("#{setting}": nil).reorder(:depth).last
    if org
      value = org[setting]
    end

    return value
  end

  # for clearity this probably be changed to get_root_org_setting
  def root_org_setting (setting)
    return find_org_root[setting]
  end

  def set_root_org_setting (settings)
    org = find_org_root
    settings.each do |setting,val|
      org[setting] = val
    end
    org.save
  end

  def find_org_root
    if self.slug&.start_with?('/')
      org = self.ancestors.find_by(depth: 0)
    else
      org = self
    end
    return org
  end


  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end
end
