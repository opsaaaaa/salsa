require 'net/http'
class RepublishController < ApplicationController
  before_action :require_organization_admin_permissions
  before_action :get_organization
  before_action :get_org_time_zone, olny: [:preview]
  before_action -> {@root_org = @organization.root}
  def preview
    get_documents
    @organizations = Organization.all.order(:lft, :rgt, :name)

    @allow_republish_btn = @organization.root.slug == request.env['SERVER_NAME'] && check_lock(@organization)
    @update_lock_url = republish_update_path(slug: @organization.full_slug)
    
    unless @root_org.republish_batch_token
      @root_org.republish_batch_token = SecureRandom.urlsafe_base64(16)
      @root_org.save!
    end
    render :layout => 'admin', :template => '/republish/preview'
  end

  def update_lock
    expire = params[:expire]
    if expire == 'false'
      @root_org.republish_at = DateTime.now

      @root_org.save!
    else
      @root_org.expire_lock
    end
    respond_to do |format|
      msg = { :status => "ok", :message => "Success!" }
      format.html  {
        render :json => @root_org.republish_at
      }
    end
  end

  private

  def get_documents path=params[:slug], page=params[:page], per=25, start_date=params[:document][:start_date], end_date=params[:document][:end_date]
    
    operation = ''
    operation += "AND lms_published_at >= '#{DateTime.parse(start_date).beginning_of_day}' " if start_date && start_date != ''
    if end_date && end_date != ''
      operation += "AND lms_published_at <= '#{DateTime.parse(end_date).end_of_day}'"
    else
      operation += "AND lms_published_at <= '#{DateTime.now.end_of_day}'"
    end

    documents = Document.where("documents.organization_id IN (?) #{operation} AND documents.updated_at != documents.created_at", @organization.self_and_descendants.pluck(:id))

    org_base = org_url_base(@organization)
    @republish_urls = documents.map {|d| "#{org_base}#{edit_document_path(id: d.edit_id)}"}

    @documents = documents.order(updated_at: :desc, created_at: :desc).page(page).per(per)

  end
end
