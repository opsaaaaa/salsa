require 'tempfile'
require 'zip'

class Admin::AuditorController < ApplicationController
  
  before_action :require_auditor_role
  before_action -> { @org = get_org }, olny: [:report, :reports, :build]

  def download
    if FileHelper::should_use_aws_s3?
      redirect_to FileHelper.presigned_url(ReportHelper.remote_file_location(get_org, params['report'])) 
    else
      send_file(ReportHelper.local_file_location(get_org, params['report']))
    end
  end

  def reportStatus
    render 'report_status', layout: '../admin/auditor/report_layout'
  end

  def archive_report
    report = ReportArchive.where(id: params[:report]).first
    report.is_archived = true
    report.save
    return redirect_to admin_auditor_reports_path(org_path:params[:org_path])
  end

  def restore_report
    report = ReportArchive.where(id: params[:report]).first
    report.is_archived = false
    report.save
    return redirect_to admin_auditor_reports_path(show_archived: true, org_path:params[:org_path])
  end

  def reports
    @reports = ReportArchive.where(
      organization_id: @org.id, 
      is_archived: params[:show_archived].present?).order(updated_at: :desc )

    if @reports.blank? && !params[:show_archived]
      @params_hash = params.permit(:account_filter, :controller, :action, :period_filter).to_hash

      report = ReportArchive.create({organization_id: @org.id, report_filters: @params_hash})
      generate_report(report.id)
      
      return redirect_to admin_auditor_reports_path(org_path:params[:org_path])
    end

    @default_report = nil
    @reports.each do |report|
      if report.payload && @org.default_account_filter && report.report_filters && report.report_filters["account_filter"] == @org.default_account_filter
        @default_report = true
      end
    end

    render 'reports', layout: '../admin/auditor/report_layout'
  end

  def report
    @report = get_report
    return redirect_to admin_auditor_reports_path(org_path:params[:org_path]) if @report.blank?

    @name_by = get_name_reports_by
    report_payload = @report.parsed_payload
    @chart_data = prep_chart_data_for_hichart(report_payload)
    @report_data = report_payload['list']
    render 'report', layout: '../admin/auditor/report_layout'
  end

  def build
    @params_hash = params.permit(:account_filter, :controller, :action).to_hash
    rebuild = params[:rebuild]
    remove_unneeded_params
 
    @period_filter = get_account_filter
 
    redirect_if_job_incomplete
 
    report = @org.report_archives.find(params[:report])

    unless report.present? && report.report_filters['account_filter'] == @period_filter
      report = @org.report_archives.all.find {|r| r.report_filters['account_filter'] == "#{@period_filter}" && !r.is_archived }
    end
 
    if report.present? && rebuild
      generate_report(report.id)
    else
      generate_report()
    end

    return redirect_to admin_auditor_report_status_path(org_path:params[:org_path])
  end

  private

  def get_name_reports_by
    @org.get_name_reports_by({
        document: '', 
        lms_course_id: :course_id
    })
  end

  def generate_report(id = nil)
    @queued = ReportHelper.generate_report_as_job @org.id, @period_filter, @params_hash, id
  end

  def prep_chart_data_for_hichart(data)
    preped = {}

    data.each do |chart_key , chart_data|
      preped[chart_key] = chart_data.first.keys.zip(
        chart_data.map(&:values).transpose
      ).to_h if chart_data.present? 
    end
    
    if data['org_chart'].present?
      preped['org_chart']['org_name'] = @report.organization.name
      preped['org_chart']['org_total'] = preped['org_chart']['total_docs'].sum
    end

    preped
  end

  def redirect_if_job_incomplete
    jobs = Que.execute("select run_at, job_id, error_count, last_error, queue, args from que_jobs where job_class = 'ReportGenerator'")
    args = [ @org.id, @period_filter, params ]
    jobs.each do |job|
      if job['args'] == args
        return redirect_to admin_auditor_report_status_path(org_path:params[:org_path])
      end
    end
  end

  def get_account_filter
    if params[:account_filter] && params[:account_filter] != ""
      return params[:account_filter]
    else
      if @org.root_org_setting("reports_use_document_meta")
        default_account_filter = @org.root_org_setting('default_account_filter')
      else
        default_account_filter = @org.all_periods.find_by(is_default:true).slug
      end
      if default_account_filter.present?
        return default_account_filter
      else
        # jump 2 weeks ahead to allow staff to review things for upcoming semester
        date = Date.today + 2.weeks
        semester = ['SP','SU','FL'][((date.month - 1) / 4)]
        return "#{semester}#{date.strftime("%y")}"
      end
    end
  end

  def get_report
    report = nil
    if params[:report]
      report = ReportArchive.where(id: params[:report]).first
      params.delete :report
    else
      #start by saving the report (add check to see if there is a report)
      reports = ReportArchive.where(organization_id: @org.id) 
      if reports.present?
        report = reports.first
      else
        report = nil
      end
    end
    return report
  end

  def remove_unneeded_params
    params.delete :authenticity_token
    params.delete :utf8
    params.delete :commit
    params.delete :rebuild
  end
  
end
