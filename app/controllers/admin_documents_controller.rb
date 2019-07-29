class AdminDocumentsController < AdminDocumentsBaseController
  before_action :get_organizations, only: [:new, :edit, :update, :index, :versions, :meta]
  before_action :require_designer_or_supervisor_permissions
  before_action :require_admin_permissions, only: [:index, :destroy]
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

  def meta
    get_document params[:document_id]
    @organization = get_org
    @document_meta = @document.meta.order(:key).page(params[:page]).per(params[:per])
  end

  def destroy
    get_document params[:id].to_i
    @document.destroy

    redirect_back(fallback_location: admin_documents_path)
  end

  private

  def get_users document
    organization_ids = [document.organization.id]
    
    @users = User.includes(:user_assignments).where(archived: false, user_assignments: { organization_id: organization_ids }).order('email', 'name')
    @users += [document.user] if !document.user.blank?
    @users = @users.uniq()
  end
end
