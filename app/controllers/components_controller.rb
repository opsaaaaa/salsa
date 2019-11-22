class ComponentsController < ApplicationController
  layout 'components'

  before_action :redirect_to_sub_org, only:[:index,:new,:show,:edit]
  before_action :require_organization_admin_permissions
  before_action :require_admin_permissions, only: [:load_components, :export_components, :import_components]

  before_action :get_organizations
  before_action :get_organization
  before_action :get_organization_levels
  before_action :get_roles

  def index
    @available_liquid_variables = component_allowed_liquid_variables true
    @components = @organization.components

    @available_component_formats = Component.valid_formats(has_role("admin"))

    @components = @components.where(category: params[:category]) if params[:category]

    @components = @components.where(format: @available_component_formats).order(:name, :slug)
  end

  def new
    @component = Component.new
    @component.organization_id = @organization.id
    @valid_slugs = @component.valid_slugs
    @available_liquid_variables = component_allowed_liquid_variables true
    @available_component_formats = Component.valid_formats(has_role("admin"))
  end

  def create

    @available_liquid_variables = component_allowed_liquid_variables true
    @component = Component.new component_params
    @component[:organization_id] = @organization[:id]
    @valid_slugs = @component.valid_slugs

    @available_component_formats = Component.valid_formats(has_role("admin"))
    set_role_validations(@component)

    respond_to do |format|
      if @component.save
        format.html { redirect_to components_path(org_path: params[:org_path]), notice: "Component was successfully created." }
        format.json { render :show, status: :created }
      else
        format.html { render :edit }
        format.json { render json: @component.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @available_liquid_variables = component_allowed_liquid_variables true
    @available_component_formats = Component.valid_formats(has_role("admin"))

    @component = Component.find_by! slug: params[:component_slug], organization: @organization, format: @available_component_formats
    @valid_slugs = @component.valid_slugs

    set_role_validations(@component)

    respond_to do |format|
      if @component.update component_params
        format.html { redirect_to components_path(org_path: params[:org_path]), notice: "Component was successfully updated." }
        format.json { render :show, status: :created }
      else
        format.html { render :edit }
        format.json { render json: @component.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @available_liquid_variables = component_allowed_liquid_variables true
    edit
  end

  def edit
    @available_liquid_variables = component_allowed_liquid_variables true
    @available_component_formats = Component.valid_formats(has_role("admin"))
    @component = Component.find_by! slug: params[:component_slug], organization: @organization, format: @available_component_formats
    @valid_slugs = @component.valid_slugs
  end

  def export_components
    @components = @organization.components
    zipfile_path = "#{ENV["ZIPFILE_FOLDER"]}/#{@organization.slug}_components.zip"
    if File.exist?(zipfile_path)
      File.delete(zipfile_path)
    end
    Zip::File.open(zipfile_path, Zip::File::CREATE) do |zipfile|
      @components.each do |component|
        if component.format == "erb"
          zipfile.get_output_stream("#{component.slug}.html.#{component.format}"){ |os| os.write component.layout }
        else
          zipfile.get_output_stream("#{component.slug}.#{component.format}"){ |os| os.write component.layout }
        end
      end
    end
    send_file (zipfile_path)
  end

  def import_components
    if !params[:file]
      flash[:error] = "You must select a file before importing components"
      return redirect_to components_path(org_path: params[:org_path])
    end
    Zip::File.open(params[:file].path) do |zipfile|
      zipfile.each do |file|
        content = file.get_input_stream.read
        component = Component.find_or_initialize_by(
          organization_id: @organization.id,
          slug: file.name.remove(/\..*/, /\b_/).gsub(/ /, '_')
        )
        set_role_validations(component)
        if params[:overwrite] == "true" || component.new_record?
          component.category = "document" if component.category.blank?
          component.category = "mailer" if File.extname(file.name).delete('.') == "liquid"
          component.name = file.name.remove(/\..*/).gsub('_',' ').titleize if component.name.blank?
          component.description = "" if component.description.blank?
          component.update(
            layout: content,
            format: File.extname(file.name).delete('.')
          )
        end
      end
    end
    return redirect_to components_path(org_path: params[:org_path]), notice: "Imported Components"
  end

  def load_components
    org = @organization
    file_paths = Dir.glob("app/views/instances/default/*.erb")
    file_paths.each do |file_path|
        component = Component.find_or_initialize_by(
          organization_id: @organization.id,
          slug: File.basename(file_path).remove(/\..*/, /\b_/).gsub(/ /, '_'),
        )
        component.update(
          name: File.basename(file_path).remove(/\..*/),
          description: "",
          category: "document",
          layout: File.read(file_path),
          format: File.extname(file_path).delete('.')
        )
    end
    return redirect_to components_path(org_path: params[:org_path]), notice: "Loaded Default Components"
  end

  private

  def set_role_validations(component)
    if has_role('admin')
      component.user_role = "admin"
    else
      component.user_role = "not_admin"
    end
  end

  def get_organization_levels
     @orgs = @organization.parents.push(@organization) + @organization.descendants
     organization_levels = @orgs.map { |h| h.slice(:slug, :level).values }
     @organization_levels = organization_levels.sort {|a,b|  a[1] <=> b[1] }
  end

  def component_params
    # ActionController::Parameters.action_on_unpermitted_parameters = :raise

    params.require(:component).permit(
      :name,
      :slug,
      :description,
      :category,
      :subject,
      :layout,
      :format,
      :role
    )
  end
end
