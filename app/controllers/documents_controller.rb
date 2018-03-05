require 'net/http'

class DocumentsController < ApplicationController

  layout 'view'

  before_action :lms_connection_information, :only => [:edit, :course, :course_list]
  before_action :lookup_document, :only => [:edit, :update]
  before_action :init_view_folder, :only => [:new, :edit, :update, :show, :course]

  def index
    redirect_to :new
  end

  def new
    if can_use_edit_token(params[:lms_course_id])
      @document = Document.new(name: 'Unnamed')

      # if an lms course ID is specified, capture it with the document
      @document[:lms_course_id] = params[:lms_course_id]

      verify_org

      @document.save!

      if params[:sub_organization_slugs]
        redirect_to edit_sub_org_document_path(id: @document.edit_id, sub_organization_slugs: params[:sub_organization_slugs])
      else
        redirect_to edit_document_path(id: @document.edit_id)
      end
    else
      redirect_to root_path, :flash => { :error => "You are not authorized to create a document" }
    end
  end

  def show
    @document = Document.find_by_view_id(params[:id])
    unless @document
      document = Document.find_by_edit_id(params[:id])

      unless document
        document_template = Document.find_by_template_id(params[:id])
        if document_template
          document = document_template.dup
          document.reset_ids
          document.save!
        end

      end

      raise ActionController::RoutingError.new('Not Found') unless document
      redirect_to edit_document_path(:id => document.edit_id, :batch_token => params[:batch_token])
      return
    end

    @calendar_only = params[:calendar_only] ? true : false

    @action = 'show'

    respond_to do |format|
      format.html {
        render :layout => 'view', :template => '/documents/content'
      }
      format.pdf{
        html = render_to_string :layout => 'view', :template => '/documents/content.html.erb'
        content = Rails.env.development? ? WickedPdf.new.pdf_from_string(html.force_encoding("UTF-8")) : html
        render :text => content, :layout => false
      }
    end
  end

  def edit
    if check_lock @organization[:slug], params[:batch_token]
      if params[:version].to_i > 0
        @document_version = params[:version].to_i
        @document = @document.versions[@document_version].reify
      else
        @document_version = @document.versions.count
      end

      verify_org
      @can_use_edit_token = can_use_edit_token(@document.lms_course_id)
      render :layout => 'edit', :template => '/documents/content'
    else
      render :layout => 'dialog', :template => '/documents/republishing'
    end
  end

  def course
    # if canvas flag is set in URL, don't try relinking again
    unless params[:canvas]
      # if clicked the create new document link on relink page, clear out the session relink value
      if params[:create_new]
        session['relink_'+params[:lms_course_id]] = nil
      # if we got here from a relink action, keep track of the document token in case the user is not logged in yet
      elsif params[:document_token] && params[:lms_course_id]
        session['relink_'+params[:lms_course_id]] = params[:document_token]
      end
    end

    begin
      @lms_course = @lms_client.get("/api/v1/courses/#{params[:lms_course_id]}", { include: 'syllabus_body' }) if @lms_client.token
    rescue
      # if a designer of the org, allow them to pass...
      if has_role('designer')
        @lms_course = { name: "Generated by Course Designer - #{params[:lms_course_id]}"}
      else
        raise ActionController::RoutingError.new('Not Authorized')
      end
    end

    if @lms_course
      @document = Document.find_by lms_course_id: params[:lms_course_id], organization: @organization

      # flag to see if there is a match on the token id
      token_matches = false

      # if no document_token is in the params, but there is a relink value matching the current course, use that, then clear it
      unless params[:document_token]
        if session['relink_'+params[:lms_course_id]]
          params[:document_token] = session['relink_'+params[:lms_course_id]]
        end
      end

      if params[:document_token]
        # check if the supplied token token_matches the document view_id
        if @document && @document[:view_id] == params[:document_token]
          token_matches = true
        end
      else
        # no token, proceed as normal
        token_matches = true
      end

      unless @document && token_matches
        # if they have a document token (read only token for now) then see if it exists
        if params[:document_token]
          @document = Document.find_by view_id: params[:document_token]

          if @document
            # we need to setup the course and associate it with canvas
            if params[:canvas]
              @document = Document.new(name: @lms_course['name'], lms_course_id: params[:lms_course_id], organization: @organization, payload: @document[:payload])
              @document.save!

              return redirect_to lms_course_document_path(lms_course_id: params[:lms_course_id])
            else
              # show options to user (make child, make new)
              @template_url = template_url

              #clear the document token out
              session.delete('relink_'+params[:lms_course_id])

              return render :layout => 'relink', :template => '/documents/relink'
            end
          end
        end

        @document = Document.new(name: @lms_course['name'], lms_course_id: params[:lms_course_id], organization: @organization)
        @document.save!

        session.delete('relink_'+params[:lms_course_id]) if session['relink_'+params[:lms_course_id]]
      end

      @document.revert_to params[:version].to_i if params[:version]

      @view_pdf_url = view_pdf_url
      @view_url = view_url
      @template_url = template_url

      # backwards compatibility alias
      @syllabus = @document

      render :layout => 'edit', :template => '/documents/content'
    else
      session[:redirect_course_id] = params[:lms_course_id]

      if params[:document_token]
        redirect_to '/oauth2/login', lms_course_id: params[:lms_course_id], document_token: params[:document_token]
      else
        redirect_to '/oauth2/login', lms_course_id: params[:lms_course_id]
      end
    end
  end

  def course_list
    raise ActionController::RoutingError.new('Not Found') unless @lms_user

    verify_org

    if params[:page]
      @page = params[:page].to_i if params[:page]
    else
      @page = 1
    end

    @lms_courses = @lms_client.get("/api/v1/courses", per_page: 20, page: @page) if @lms_client.token

    render :layout => 'organizations', :template => '/documents/from_lms'
  end

  def update
    canvas_course_id = params[:canvas_course_id]
    document_version = params[:document_version]
    saved = false
    republishing = true
    verify_org
    if can_use_edit_token(@document.lms_course_id)
      if check_lock @organization[:slug], params[:batch_token]
        republishing = false;
        if canvas_course_id && !@organization.skip_lms_publish
          # publishing to canvas should not save in the Document model, the canvas version has been modified
          saved = update_course_document(canvas_course_id, request.raw_post, @organization[:lms_info_slug]) if params[:canvas] && canvas_course_id
        else
          if(params[:canvas_relink_course_id])
            #find old document in this org with this id, set to null
            old_document = Document.find_by lms_course_id: params[:canvas_relink_course_id], organization: @organization
            old_document.update(lms_published_at: nil, lms_course_id: nil)

            #set this document's canvas_course_id
            @document.lms_course_id = params[:canvas_relink_course_id]
          end

          if document_version && @document.versions.count == document_version.to_i
            @document.payload = request.raw_post

            @document.payload = nil if @document.payload == ''
            @document.lms_published_at = DateTime.now

            @document.save!
            saved = true;
          end
        end
      end
    end

    respond_to do |format|
      if can_use_edit_token(@document.lms_course_id) != true
        msg = { :status => "error", :message => "You do not have permisson to save this document"}
      elsif republishing
       msg = { :status => "error", :message => "Documents for this organization are currently being republished. Please copy your changes and try again later.", :version => @document.versions.count }
      elsif !saved
        msg = { :status => "error", :message => "This is not a current version of this document! Please copy your changes and refresh the page to get the current version.", :version => @document.versions.count }
      else
        msg = { :status => "ok", :message => "Success!", :version => @document.versions.count }
      end
      format.json  {
        view_url = document_url(@document.view_id, :only_path => false)
        render :json => msg
      }
    end
  end

  protected
  def can_use_edit_token(lms_course_id = nil)
    if @organization[:enable_anonymous_actions]
      true
    elsif has_role('designer')
      true
    elsif is_lms_authenticated_user? && has_canvas_access_token? && lms_course_id
      if @document == nil
        true
      elsif lms_course_id == nil
        true
      elsif authorized_to_edit_course(lms_course_id)
        true
      end
    else
      false
    end
  end

  def authorized_to_edit_course lms_course_id
    courses = get_canvas_courses
    if courses.pluck("id").include?(lms_course_id.to_i)
      true
    else
      false
    end
  end

  def get_canvas_courses
    lms_connection_information
    canvas_access_token = session[:canvas_access_token]["access_token"]
    canvas = Canvas::API.new(:host => session[:oauth_endpoint], :token => canvas_access_token)
    courses = canvas.get("/api/v1/courses?per_page=50")
  end

  def is_lms_authenticated_user?
    if session[:lms_authenticated_user]
      true
    else
      false
    end
  end

  def has_canvas_access_token?
    if session[:canvas_access_token] != nil && session[:canvas_access_token] != ""
      true
    else
      false
    end
  end

  def view_pdf_url
    if Rails.env.production?
      "https://s3-#{APP_CONFIG['aws_region']}.amazonaws.com/#{APP_CONFIG['aws_bucket']}/hosted/#{@document.view_id}.pdf"
    else
      "http://#{request.env['SERVER_NAME']}#{redirect_port}/#{sub_org_slugs}SALSA/#{@document.view_id}.pdf"
    end
  end

  def view_url
    "http://#{request.env['SERVER_NAME']}#{redirect_port}/#{sub_org_slugs}SALSA/#{@document.view_id}"
  end

  def template_url
    "http://#{request.env['SERVER_NAME']}#{redirect_port}/#{sub_org_slugs}SALSA/#{@document.template_id}"
  end

  def sub_org_slugs
    params[:sub_organization_slugs] + '/' if params[:sub_organization_slugs]
  end

  def lookup_document
    @document = Document.find_by_edit_id(params[:id])

    raise ActionController::RoutingError.new('Not Found') unless @document
    @view_pdf_url = view_pdf_url
    @view_url = view_url
    @template_url = template_url

    # use the component that was used when this document was created
    if @document.component_version
      @document.component.revert_to @document.component_version
    end

    # backwards compatibility alias
    @syllabus = @document
  end

  def update_course_document course_id, html, lms_info_slug
    lms_connection_information

    @lms_client.put("/api/v1/courses/#{course_id}", { course: { syllabus_body: html } })

    if(lms_info_slug)
      @lms_client.put("/api/v1/courses/#{course_id}/#{lms_info_slug}", { wiki_page: { body: "<p><a id='edit-gui-salsa' href='#{ document_url(@document[:edit_id]) }' target='_blank'>Edit your <abbr title='Styled and Accessible Learning Service Agreement'>SALSA</abbr></a></p>", hide_from_students: true } })
    end

    if @document
      @document.update(lms_published_at: DateTime.now, lms_course_id: course_id)
    end
  end

  def verify_org
    document_slug = request.env['SERVER_NAME']

    if @document[:edit_id]
      @salsa_link = document_path(@document[:edit_id])

      if params[:sub_organization_slugs]
        document_slug += '/' + params[:sub_organization_slugs]

        if @document[:edit_id]
          @salsa_link = sub_org_document_path @document[:edit_id], sub_organization_slugs: params[:sub_organization_slugs]
        else
          @salsa_link = new_sub_org_document_path sub_organization_slugs: params[:sub_organization_slugs]
        end
      end
    end

    if @organization && @organization[:id]
      org = @organization
    else
      if session[:authenticated_institution] && session[:authenticated_institution] != '' && session[:authenticated_institution] != document_slug
        document_slug = session[:authenticated_institution] + '.' + document_slug
      end

      # find the org to bind this to
      org = Organization.find_by slug: document_slug
    end

    # if there is no org yet, show an error
    raise "error: no org found matching #{document_slug}"  unless org

    @document[:organization_id] = org[:id] if @document

    @organization = org
  end
end
