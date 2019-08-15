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
    if @organization.setting("reports_use_document_meta")
      org_ids = @organization.id
      puts 'Getting Document Meta'
      if false && @organization.root_org_setting("enable_workflow_report")
        @report_data = self.get_workflow_document_meta docs&.pluck(:id)
      else
        @report_data = self.get_document_meta org_slug, account_filter, params
      end
      puts 'Retrieved Document Meta'
    else
      org_ids = @organization.self_and_descendants.pluck(:id)
      puts 'Getting local report data'
      # @report_data = DocumentMeta.find_by_sql(document_record_query_sql(@organization.self_and_descendants, @organization.get_name_reports_by))
      @report_data = self.get_local_report_data(@organization.self_and_descendants, @organization.get_name_reports_by, account_filter, params)
      puts 'Retrieved local report data'
    end

    if !account_filter_blank?(account_filter) && !@organization.root_org_setting("enable_workflow_report")
      docs = Document.where(organization_id: org_ids, id: @report_data.map(&:document_id)).where('updated_at != created_at').all
    elsif !@organization.root_org_setting("enable_workflow_report")
      docs = Document.where(organization_id: org_ids).where('updated_at != created_at').all
    end

    #store it
    @report.generating_at = nil
    @report.payload = @report_data.to_json
    @report.save!

    self.archive org_slug, report_id, @report_data, account_filter, docs
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

  def self.get_workflow_document_meta doc_ids
    DocumentMeta.where(document_id: doc_ids)
  end

  def self.get_document_meta org_slug, account_filter, params
    # raise params.inspect
    # query_parameters = {}
    
    # org = Organization.find_by slug: org_slug

    # if !account_filter_blank?(account_filter)
    #   query_parameters[:account_filter] = "%#{account_filter}%"
    #   account_filter_sql = "AND n.value LIKE :account_filter AND a.key = 'account_id'"
    # else
    #   account_filter_sql = nil
    # end

    # start_filter = ''
    # if params[:start]
    #   start = params[:start] = params[:start].gsub(/[^\d-]/, '')
    #   if start != ''
    #     query_parameters[:start] = params[:start]
    #     start_filter = "AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)"
    #   end
    # end

    # limit_sql = nil
    # if params[:page]
    #     query_parameters[:offset] = (params[:page] || 1).to_i
    #     query_parameters[:limit] = (params[:per] || 1).to_i
    #     limit_sql = 'offset :offset limit :limit'
    # end

    # query_parameters[:org_id] = org[:id]
    # query_parameters[:org_id_string] = org[:id].to_s
    # raise [account_filter_sql, limit_sql, start_filter, query_parameters].inspect
    # # ["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, "", {:account_filter=>"%{\"account_filter\"=>\"FL17\"}%", :org_id=>1, :org_id_string=>"1"}]
    # DocumentMeta.find_by_sql([document_meta_query_sql(account_filter_sql, limit_sql, start_filter), query_parameters])


    query_options = { 
      :start => "AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)",
      :account_filter=>"AND n.value LIKE :account_filter AND a.key = 'account_id'", 
      :limit=>"offset :offset limit :limit", 
      :offset=>nil,
      :org_id=>"AND d.organization_id IN ( :org_id )",
      :org_id_string=>"a.root_organization_id = :org_id_string"
    }
    # params[:start] = ''
    # if params[:start]
    #   if (params[:start] = params[:start].gsub(/[^\d-]/, '')) == ''
    #     query_options[:start] = "AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)" 
    #   end
    # end

    org_id = Organization.find_by(slug: org_slug).id
    params[:org_id_string] = org_id.to_s
    params[:org_id] = org_id
    # # raise params[:start].inspect
    params[:account_filter] = "%#{account_filter}%" unless account_filter_blank?(account_filter)
    params[:offset] = (params[:page] || 1).to_i if params[:page]
    params[:limit] = (params[:per] || 1).to_i if params[:page]

    query_settings = collect_query_settings params, query_options
    
    if query_settings[:params][:start].nil? || (query_settings[:params][:start] = query_settings[:params][:start].gsub(/[^\d-]/, '')) == ''
      query_settings[:strings][:start] = ''
    end
    # # query_settings[:strings][:start] = ''
    # # if params[:start]
    # #   start = params[:start] = params[:start].gsub(/[^\d-]/, '')
    # #   if start != ''
    # #     query_settings[:params][:start] = params[:start]
    # #     query_settings[:strings][:start] = "AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)"
    # #   end
    # # end
    # # query_settings[:params][:org_id] = org_id.to_s
    query_strings = query_settings[:strings]
    # # raise query_settings[:strings].inspect
    # # raise ([
    # # raise ([
    # # raise [
    # #     query_strings[:account_filter], 
    # #     query_strings[:limit], 
    # #     query_strings[:start] , query_settings[:params] ].inspect
    # raise ([[
    #     query_strings[:account_filter], 
    #     query_strings[:limit], 
    #     query_strings[:start] 
    # ],
    #   query_settings[:params]
    # ]).inspect
    # [["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, ""], {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}]
    # raise ([
    #   ([account_filter_sql, limit_sql, start_filter]),
    #   query_parameters
    # ]).inspect
    # [["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, ""], {:account_filter=>"%{\"account_filter\"=>\"FL17\"}%", :org_id=>1, :org_id_string=>"1"}]
    # DocumentMeta.find_by_sql([
    #   document_meta_query_sql(account_filter_sql, limit_sql, start_filter),
    #   query_parameters
    # ])
    # DocumentMeta.find_by_sql([
    #   document_meta_query_sql("AND n.value LIKE :account_filter AND a.key = 'account_id'",nil, ""), 
    #   {:account_filter=>"%{\"account_filter\"=>\"FL17\"}%", :org_id=>1, :org_id_string=>"1"}
    # ])
    # DocumentMeta.find_by_sql([
    #   document_meta_query_sql("AND n.value LIKE :account_filter AND a.key = 'account_id'",nil, ""), 
    #   {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}
    # ])
    # ["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, "", {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}]
    query_parameters = Hash.new
    # [query_settings[:params]]
    query_settings[:params].each {|k,v| query_parameters[k] = v}
    # query_parameters = {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}
    # raise JSON.parse(query_parameters.to_json).inspect
    # {"controller":"admin/auditor","action":"reports","org_id_string":"1","org_id":1}
    # {"controller":"admin/auditor","action":"reports","org_id_string":"1","org_id":1}
    # raise ({:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}).inspect
    DocumentMeta.find_by_sql([document_meta_query_sql(
        query_strings[:account_filter], 
        query_strings[:limit], 
        query_strings[:start] 
      ),
      # query_parameters
      query_settings[:params]
      # {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}
      # {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}
    ])
    # ["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, "", {:org_id_string=>"1", :org_id=>1, :account_filter=>"%{\"account_filter\"=>\"FL17\"}%"}]
    # ["AND n.value LIKE :account_filter AND a.key = 'account_id'", nil, "", {:account_filter=>"%{\"account_filter\"=>\"FL17\"}%", :org_id=>1, :org_id_string=>"1"}]

    # raise query_settings.inspect
    # DocumentMeta.find_by_sql([document_meta_query_sql( query_settings[:strings] ), query_settings[:params] ])
    # DocumentMeta.find_by_sql([document_report_data_query_sql(query_settings[:strings]), query_settings[:params]])
  end

  def self.collect_query_settings params, query_options
    params = params.symbolize_keys
    query_options = query_options.symbolize_keys
    query_strings = {}
    query_parameters = {}
    params.each {|k,v| query_parameters[k] = v if query_options.has_key?(k) }
    query_options.each { |k,v| query_strings[k] = v unless v.nil? || !query_parameters.has_key?(k) }
    { params: query_parameters, strings: query_strings }
  end

  def self.get_local_report_data org_ids, name_by = 'docs.name', account_filter = nil, params = nil
    query_options = { 
      :name_by=>":name_by as name,", 
      :account_filter=>"AND n.value LIKE :account_filter AND a.key = 'account_id'", 
      :start=>"AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)", 
      :limit=>"offset :offset limit :limit", 
      :period_id=>"AND ( docs.period_id = :period_id )", 
      :org_ids=>"AND docs.organization_id IN ( :org_ids )",
      :offset=>nil
    }
    subs = {
      document: :docs, 
      organization: :orgs, 
      workflow_step: :ws,
      period: :pd  
    }
    # params[:name_by] = @organization.get_name_reports_by
    params[:name_by] = 'document.lms_course_id'
    subs.each { |k, v| params[:name_by][k.to_s] &&= v.to_s }
    params[:org_ids] = org_ids
    params[:account_filter] = "%#{account_filter}%" unless account_filter_blank?(account_filter)
    params[:offset] = (params[:page] || 1).to_i if params[:page]
    params[:limit] = (params[:per] || 1).to_i if params[:page]

    query_settings = collect_query_settings params, query_options
    # raise query_settings[:params].inspect
    DocumentMeta.find_by_sql([document_report_data_query_sql(query_settings[:strings]), query_settings[:params]])
  end

  # def self.document_report_data_query_sql orgs = false, name_by = 'docs.name', period_id = false, limit = false
  def self.document_report_data_query_sql sql_strings
    <<-SQL.gsub(/^ {4}/, '')
      SELECT DISTINCT
        docs.lms_course_id as course_id,
        orgs.lms_account_id as account_id, 
        -- root_org.name as account,
        orgs.parent_id as parent_id,
        docs.id as document_id,
        docs.id as id,
        -- docs.name docs.lms_course_id as name,
        #{sql_strings[:name_by]}
        -- cc.value as course_code,
        -- et.value as enrollment_term_id,
        -- sis.value as sis_course_id,
        pd.start_date as start_at,
        pd.duration as duration,
        -- pd.end_date asend_at,
        p_org.name as parent_account_name,
        ws.name as workflow_state, 
        -- ts.value as total_students,
        docs.edit_id as edit_id,
        docs.view_id as view_id,
        docs.lms_published_at as published_at,
        orgs.id as organization_id,
        pd.id as period_id

      FROM documents as docs

      LEFT JOIN organizations as orgs
        ON docs.organization_id = orgs.id
        AND docs.updated_at != docs.created_at

      LEFT JOIN organizations as p_org
        ON orgs.parent_id = p_org.id

      -- LEFT JOIN organization as root_org
      -- AND root_org.parent_id = nil
      -- AND root_org.depth = 0

      LEFT JOIN workflow_steps as ws
        ON docs.workflow_step_id = ws.id

      LEFT JOIN periods as pd
        ON docs.period_id = pd.id

      WHERE docs.created_at != docs.updated_at         
        #{sql_strings[:period_id]}
        #{sql_strings[:org_ids]}

      ORDER BY docs.lms_published_at, orgs.id

      #{sql_strings[:limit]}
    SQL
  end

  def self.document_meta_query_sql account_filter_sql, limit_sql, start_filter
    <<-SQL.gsub(/^ {4}/, '')
      SELECT DISTINCT a.lms_course_id as course_id,
        a.value as account_id,
        acn.value as account,
        p.value as parent_id,
        d.id as document_id,
        n.value as name,
        cc.value as course_code,
        et.value as enrollment_term_id,
        sis.value as sis_course_id,
        start.value as start_at,
        p.value as parent_id,
        pn.value as parent_account_name,
        end_date.value as end_at,
        ws.value as workflow_state,
        ts.value as total_students,
        d.edit_id as edit_id,
        d.view_id as view_id,
        d.lms_published_at as published_at

      -- prefilter the account id and course id meta information so joins will be faster (maybe...?)
      FROM document_meta as a

      -- join the name meta information
      LEFT JOIN
        document_meta as n ON (
          a.lms_course_id = n.lms_course_id
          AND a.root_organization_id = n.root_organization_id
          AND n.key = 'name'
        )

      -- join the account name
      LEFT JOIN
        organization_meta as acn ON (
          a.value = acn.lms_organization_id
          AND a.root_organization_id = acn.root_id
          AND acn.key = 'name'
        )

      -- join the account parent id
      LEFT JOIN
        organization_meta as p ON (
          acn.lms_organization_id = p.lms_organization_id
          AND acn.root_id = p.root_id
          AND p.key = 'parent_account_id'
        )

        -- join the account parent id
      LEFT JOIN
        organization_meta as pn ON (
          p.value = pn.lms_organization_id
          AND acn.root_id = pn.root_id
          AND pn.key = 'name'
        )

      -- join the course code meta infromation
      LEFT JOIN
        document_meta as cc ON (
          a.lms_course_id = cc.lms_course_id
          AND a.root_organization_id = cc.root_organization_id
          AND cc.key = 'course_code'
        )

      -- join the enrollment term meta information
      LEFT JOIN
        document_meta as et ON (
          a.lms_course_id = et.lms_course_id
          AND a.root_organization_id = et.root_organization_id
          AND et.key = 'enrollment_term_id'
        )

      -- join the sis course id meta information
      LEFT JOIN
        document_meta as sis ON (
          a.lms_course_id = sis.lms_course_id
          AND a.root_organization_id = sis.root_organization_id
          AND sis.key = 'sis_course_id'
        )

      -- join the start date meta information
      LEFT JOIN
        document_meta as start ON (
          a.lms_course_id = start.lms_course_id
          AND a.root_organization_id = start.root_organization_id
          AND start.key = 'start_at'
  
          #{start_filter}
        )

      -- join the end_date date meta information
      LEFT JOIN
        document_meta as end_date ON (
          a.lms_course_id = end_date.lms_course_id
          AND a.root_organization_id = end_date.root_organization_id
          AND end_date.key = 'end_at'
        )

      -- join the workflow state meta information
      LEFT JOIN
        document_meta as ws ON (
          a.lms_course_id = ws.lms_course_id
          AND a.root_organization_id = ws.root_organization_id
          AND ws.key = 'workflow_state'
        )

      -- join the total_students meta information
      LEFT JOIN
        document_meta as ts ON (
          a.lms_course_id = ts.lms_course_id
          AND a.root_organization_id = ts.root_organization_id
          AND ts.key = 'total_students'
          AND ts.value != '0'
        )

      -- join the SALSA document
      LEFT JOIN
        documents as d ON (
          a.lms_course_id = d.lms_course_id
          AND d.organization_id IN ( :org_id )
          -- {sql_strings[:org_id]}
        )

      WHERE
        a.root_organization_id = :org_id_string
        #{account_filter_sql}

      ORDER BY pn.value, acn.value, n.value, a.lms_course_id

      #{limit_sql}
    SQL
  end

end
