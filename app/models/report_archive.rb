class ReportArchive < ApplicationRecord
  belongs_to :organization

  def parsed_payload
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

end
