class ReportArchive < ApplicationRecord
  
  belongs_to :organization
  before_validation :use_default_period_slug_on_blank_account_filter

  def parsed_payload
    return {:list=>[]} if self.payload.blank?
    data = JSON.parse(self.payload)
    return data if data.is_a?(Hash) 
    return {'list'=> data} if data.is_a?(Array)
  end

  def used_meta?
    r = self.used_document_meta
    if r.nil?
      r = self.parsed_payload[:org_chart].blank?
      set_used_document_meta(r)
    end
    r
  end

  def set_used_document_meta(val)
    self.used_document_meta = val
    self.save
  end

  def use_default_period_slug_on_blank_account_filter
    if self.organization.root_org_setting("reports_use_document_meta")
      self.report_filters['account_filter'] = "#{self.organization.root_org_setting('default_account_filter')}"
    else
      self.report_filters['account_filter'] = self.organization.periods.find_by(is_default: true).slug.upcase if 
        self.report_filters['account_filter'].blank?
    end  
  end
end
