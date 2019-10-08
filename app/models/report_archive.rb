class ReportArchive < ApplicationRecord
  
  belongs_to :organization
  before_validation :use_default_on_blank_account_filter

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

  def use_default_on_blank_account_filter
    if self.report_filters['account_filter'].blank?
      if self.organization.root_org_setting("reports_use_document_meta")
        self.report_filters['account_filter'] = "#{self.organization.root_org_setting('default_account_filter')}"
      else
        self.report_filters['account_filter'] = self.organization.periods.find_by(is_default: true).slug
      end  
    end
  end

  def filter_types filters = nil
    types = ['account_filter','lms_course_filter']
    return types if filters.nil?
    return filters.select {|k,v| types.include?(k.to_s) && v.present?}
  end

  def filters
    filter_types(self.report_filters)
  end

  def pretty_filters join = ", "
    self.filters.map {|k,v| v.sub(/\A%/,"").split("%")}.flatten.join(join)
  end

  def filters_match?(filters)
    filter_types(filters).symbolize_keys == self.filters.symbolize_keys
  end

end
