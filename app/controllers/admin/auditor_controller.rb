require 'tempfile'
require 'zip'

class Admin::AuditorController < ApplicationController

  before_action :require_auditor_role
  before_action -> { @org = get_org }, olny: [:report, :reports]

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
      @params_hash = params.permit(:account_filter, :controller, :action).to_hash
      @account_filter = @org.default_account_filter[:account_filter]
      @params_hash[:account_filter] = @account_filter

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
    @params_hash = params.permit(:account_filter, :controller, :action).to_hash
    rebuild = params[:rebuild]
    
    remove_unneeded_params

    @account_filter = get_account_filter
    params[:account_filter] = @account_filter

    get_report
    return redirect_to admin_auditor_reports_path(org_path:params[:org_path]) if @report.nil?
    
    org_chart_data = get_org_chart_data    

    if !@report || rebuild
      redirect_if_job_incomplete
      generate_report(@report.id)
      redirect_to admin_auditor_report_path(org_path:params[:org_path])
    else
      if !@report.payload && !@queued
        generate_report(@report.id)
        return redirect_to admin_auditor_report_status_path(org_path:params[:org_path])
      end
      @report_data = JSON.parse(@report.payload)
      render 'report', layout: '../admin/auditor/report_layout'
    end
  end

  private

  def generate_report(id = nil)
    @queued = ReportHelper.generate_report_as_job @org.id, @account_filter, @params_hash, id
  end

  def get_org_chart_data
    @org.self_and_descendants.collect {|o| [name: o.name, doc_count: o.documents.count, depth: o.depth]}
  end

  def redirect_if_job_incomplete
    jobs = Que.execute("select run_at, job_id, error_count, last_error, queue, args from que_jobs where job_class = 'ReportGenerator'")
    args = [ @org.id, @account_filter, params ]
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
      if @org.default_account_filter
        return @org.default_account_filter[:account_filter]
      else
        # jump 2 weeks ahead to allow staff to review things for upcoming semester
        date = Date.today + 2.weeks
        semester = ['SP','SU','FL'][((date.month - 1) / 4)]
        return "#{semester}#{date.strftime("%y")}"
      end
    end
  end

  def get_report
    if params[:report]
      @report = ReportArchive.where(id: params[:report]).first
      params.delete :report
    else
      #start by saving the report (add check to see if there is a report)
      reports = ReportArchive.where(organization_id: @org.id) 
      if !reports.blank?
        if reports.count == 1
          report = @reports.first;
        else
          report = nil
        end
      end
    end
  end

  def remove_unneeded_params
    params.delete :authenticity_token
    params.delete :utf8
    params.delete :commit
    params.delete :rebuild
  end
  
end
