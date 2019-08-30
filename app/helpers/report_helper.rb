require 'tempfile'
require 'zip'

module ReportHelper
  def self.generate_report_as_job (org_id, account_filter, params, report_id = nil)
    @report = ReportArchive.find(report_id) if report_id
    @report = ReportArchive.create({organization_id: @org_id, report_filters: params}) unless report_id

    org = Organization.find(org_id)
    @report.generating_at = Time.now
    @report.save!(touch:false)

    # ReportHelper.generate_report Organization.find(org_id).slug, account_filter, params, @report.id
    ReportGenerator.enqueue org_id, account_filter, params, @report.id 
  end

  def self.generate_report (org_slug, account_filter, params, report_id)
    @organization = Organization.find_by slug: org_slug
    @report = ReportArchive.where(id: report_id).first

    if !account_filter_blank?(account_filter) && @organization.root_org_setting("enable_workflow_report")
      docs = Document.where(workflow_step_id: WorkflowStep.where(organization_id: @organization.parents.push(@organization.id), step_type: "end_step").pluck(:id), organization_id: @organization.id, period_id: Period.where(slug: account_filter)).where('updated_at != created_at').all
    elsif @organization.root_org_setting("enable_workflow_report")
      docs = Document.where(workflow_step_id: WorkflowStep.where(organization_id: @organization.parents.push(@organization.id), step_type: "end_step").pluck(:id), organization_id: @organization.id).where('updated_at != created_at').all
    end
    # get the report data (slow process... only should run one at a time)
    @report.used_document_meta = @organization.setting("reports_use_document_meta")
    if @organization.setting("reports_use_document_meta")
      puts 'Getting Document Meta'
      org_ids = @organization.id
      @report_data = get_meta_report docs, org_slug, account_filter, params
      puts 'Retrieved Document Meta'
    else
      puts 'Getting local report data'
      org_ids = @organization.self_and_descendants.pluck(:id)
      @report_data = self.get_org_report(@organization.self_and_descendants.pluck(:id), account_filter, params)
      puts 'Retrieved local report data'
    end

    if !account_filter_blank?(account_filter) && !@organization.root_org_setting("enable_workflow_report")
      docs = Document.where(organization_id: org_ids, id: @report_data[:list].map(&:document_id)).where('updated_at != created_at').all
    elsif !@organization.root_org_setting("enable_workflow_report")
      docs = Document.where(organization_id: org_ids).where('updated_at != created_at').all
    end

    #store it
    @report.generating_at = nil
    @report.payload = @report_data.to_json
    @report.save!

    self.archive org_slug, report_id, @report_data[:list], account_filter, docs
    puts 'Report Generated'
  end

  def self.account_filter_blank? account_filter
    return (account_filter.blank? || account_filter == {"account_filter"=>""})
  end
  
  def self.archive (org_slug, report_id, report_data, account_filter=nil, docs)
    report = ReportArchive.find_by id: report_id
    @organization = Organization.find_by slug: org_slug
    FileUtils.rm zipfile_path(org_slug, report_id), :force => true   # never raises exception

    Zip::File.open(zipfile_path(org_slug, report_id), Zip::File::CREATE) do |zipfile|
      zipfile.get_output_stream('content.css'){ |os| os.write CompassRails.sprockets.find_asset('application.css').to_s }
      
      if @organization.root_org_setting("export_type")== "Program Outcomes"
        document_metas = []
      else
        document_metas = {}
      end
      docs.each do |doc|
        doc_report_data = (report_data.select {|rep| rep["document_id"] == doc.id }).first
        doc_path = "#{doc_folder(doc)}#{doc_file_name(doc,doc_report_data)}"

        if @organization.root_org_setting("track_meta_info_from_document") && @organization.root_org_setting("export_type")== "Program Outcomes"
          program_outcomes_format(doc, document_metas)
        elsif @organization.root_org_setting("track_meta_info_from_document") && dm = "#{DocumentMeta.where("key LIKE :prefix AND document_id IN (:document_id)", prefix: "salsa_%", document_id: doc.id).select(:key, :value).to_json(:except => :id)}" != "[]"
          document_metas["lms_course-#{doc.lms_course_id}"] = JSON.parse(dm)
          zipfile.get_output_stream("#{doc_path}_document_meta.json"){ |os| os.write JSON.pretty_generate(JSON.parse(dm)) }
        end
        # Two arguments:
        # - The name of the file as it will appear in the archive
        # - The original file, including the path to find it
        # rendered_doc = render_to_string :layout => "archive", :template => "documents/content"
        rendered_doc = ApplicationController.new.render_to_string(layout: 'archive',partial: 'documents/content', locals: {doc: doc, organization: @organization, :@organization => @organization})
        zipfile.get_output_stream("#{doc_path}.html") { |os| os.write rendered_doc }
      end
      if @organization.root_org_setting("track_meta_info_from_document") && document_metas != {}
        zipfile.get_output_stream("document_meta.json"){ |os| os.write document_metas.to_json  }
      end
    end
    FileHelper.upload_file(self.remote_file_location(@organization, report_id), zipfile_path(org_slug, report_id)) if FileHelper::should_use_aws_s3?
  end
        
  def self.doc_folder doc
    folder = "#{doc.organization.path}/"
    folder.push("#{doc.period&.slug}/") if @organization.root_org_setting("enable_workflow_report")
    folder = nil if folder == "/"
    folder
  end

  def self.doc_file_name(document,report_data)
    name_by = @organization.get_name_reports_by.split(".")
    file_name = binding.local_variable_get(name_by[0])[name_by[1]].to_s
    file_name = document.name if file_name.blank?
    "#{file_name.gsub(/[^A-Za-z0-9]+/, '_')}_#{document.id}"
  end
  
  def self.remote_file_location(org, report_id)
    org.self_and_ancestors.pluck('slug').join('/') + "/#{org.slug}_#{report_id}.zip"
  end

  def self.local_file_location(org, report_id)
    zipfile_path org.slug, report_id
  end

  def self.zipfile_path (org_slug, report_id)
    return "#{ENV['ZIPFILE_FOLDER']}/#{org_slug}_#{report_id}.zip" if FileHelper::should_use_aws_s3?
    "#{ENV['APP_HOME']}/storage/#{ENV['ZIPFILE_FOLDER']}/#{org_slug.gsub(/\//,'')}_#{report_id}.zip".sub('//','/')
  end

  def self.program_outcomes_format doc, document_metas
    dms = DocumentMeta.where("key LIKE :prefix AND document_id IN (:document_id)", prefix: "salsa_%", document_id: doc.id)
    dms_array = []
    dms&.each do |dm|
      salsa_hash = Hash.new
      salsa_outcome = dm.key.split("_")[1].split("-")
      if salsa_outcome.length >= 3
        if salsa_outcome.length > 3
          salsa_outcome_type = "#{salsa_outcome[1]}: " + salsa_outcome[2..-2].join(' ')
        else
          salsa_outcome_type = salsa_outcome[1]
        end
        salsa_hash[:lms_course_id] = "#{dm.lms_course_id}"
        salsa_hash[:salsa_outcome] = salsa_outcome[0]
        salsa_hash[:salsa_outcome_type] = salsa_outcome_type
        salsa_hash[:salsa_outcome_id] = salsa_outcome.last
        salsa_hash[:salsa_outcome_text] = dm.value
        salsa_hash[:key] = ""
        salsa_hash[:value] = ""
      else
        salsa_hash[:lms_course_id] = "#{dm.lms_course_id}"
        salsa_hash[:salsa_outcome] = ""
        salsa_hash[:salsa_outcome_type] = ""
        salsa_hash[:salsa_outcome_id] = ""
        salsa_hash[:salsa_outcome_text] = ""
        salsa_hash[:key] = dm.key
        salsa_hash[:value] = dm.value

      end
      document_metas.push JSON.parse(salsa_hash.to_json)
      dms_array.push JSON.parse(salsa_hash.to_json)
    end
  end

  def self.get_meta_report docs, org_slug, account_filter, params = {}
    if @organization.root_org_setting("enable_workflow_report")
      report_data = self.get_workflow_document_meta docs&.pluck(:id)
    else
      report_data = self.get_document_meta org_slug, account_filter, params
    end
    {
      list: report_data,
      meta_chart: {}
    }
  end

  def self.get_org_report org_ids, account_filter = nil, params = {}
    {
      list: get_local_report_data(org_ids, account_filter, params),
      org_chart: get_org_chart_data(org_ids, params)
    }
  end
  
  def self.get_workflow_document_meta doc_ids
    DocumentMeta.where(document_id: doc_ids)
  end

  def self.get_local_report_data org_ids, account_filter = nil, params = {}
    SqlQueryHelper.get_local_report_data org_ids, account_filter, params
  end
  
  def self.get_org_chart_data org_ids, params = {}
    SqlQueryHelper.get_org_chart_data org_ids, params
  end

  def self.get_document_meta org_slug, account_filter, params = {}
    SqlQueryHelper.get_document_meta org_slug, account_filter, params
  end

end