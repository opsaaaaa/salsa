class AdminDocumentsController < AdminDocumentsBaseController
  before_action :get_organizations, only: [:new, :edit, :update, :index, :versions]
  before_action :require_designer_permissions
  before_action :require_admin_permissions, only: [:index]
  before_action :set_paper_trail_whodunnit

  layout 'admin'

  def index
    @documents = Document.where.not(view_id: nil).reorder(created_at: :desc).page(params[:page]).per(params[:per])
  end

  def new
    @document = Document.new
  end

  def edit
    super

    get_users @document
  end

  def versions
    get_document params[:id]
    @document_versions = @document.versions.where(event: "update").page(params[:page]).per(params[:per])
  end

  private

  def get_users
    if params[:controller] == 'admin_documents'
      organization_ids = @organizations.pluck(:id)
    else
      organization_ids = document.organization.descendants.pluck(:id) + [document.organization.id]
    end

    @users = User.includes(:user_assignments).where(archived: false, user_assignments: { organization_id: organization_ids })
    @users += [document.user] if !document.user.blank?
    @users = @users.uniq()
  private

  def get_document id=params[:id]
    @document = Document.find(id)
    raise('Insufficent permissions for this document') unless has_role('designer', @document.organization)
  end
end
