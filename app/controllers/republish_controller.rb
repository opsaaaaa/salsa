require 'net/http'
class RepublishController < ApplicationController
  before_action :require_organization_admin_permissions
  def preview
    get_documents
    @organizations = Organization.all.order(:lft, :rgt, :name)

    @allow_republish_btn = @organization.root.slug == request.env['SERVER_NAME']
    @update_lock_url = republish_update_path(slug: @organization.full_slug)
    
    if !@organization.republish_batch_token
      @organization.republish_batch_token = SecureRandom.urlsafe_base64(16)
    end
    @organization.save!
    get_org_time_zone

    render :layout => 'admin', :template => '/republish/preview'
  end

  def update_lock
    expire = params[:expire]
    @organization = find_org_by_path params[:slug]
    root_org = @organization.root
    if expire == 'false'
      root_org.republish_at = DateTime.now

      root_org.save!
    else
      expire_lock
    end
    respond_to do |format|
      msg = { :status => "ok", :message => "Success!" }
      format.html  {
        render :json => root_org.republish_at
      }
    end
  end

  def expire_lock
    root_org = @organization.root
    root_org.republish_at = nil
    root_org.republish_batch_token = nil
    root_org.save!
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

    if path
      @organization = find_org_by_path path

      documents = Document.where("documents.organization_id IN (?) #{operation} AND documents.updated_at != documents.created_at", @organization.self_and_descendants.pluck(:id))
    else
      documents = Document.where("documents.organization_id IS NULL #{operation} AND documents.updated_at != documents.created_at")
    end

    org_base = org_url_base(@organization)
    @republish_urls = documents.map {|d| "#{org_base}#{edit_document_path(id: d.edit_id)}"}

    @documents = documents.order(updated_at: :desc, created_at: :desc).page(page).per(per)

  end
end
