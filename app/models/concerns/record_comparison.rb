
module RecordComparison
  extend ActiveSupport::Concern
  
  def same_record_as? record
    return record.is_a?(self.class) && record.id == self.id
  end

end