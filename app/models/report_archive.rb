class ReportArchive < ApplicationRecord
  belongs_to :organization

  def parsed_payload
    data = JSON.parse(self.payload)
    return data if data.is_a?(Hash) 
    return {'list'=> data} if data.is_a?(Array)
  end

end
