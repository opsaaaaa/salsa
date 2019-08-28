
module Populate
  extend ActiveSupport::Concern
  
  def populate(fills)
    fills.each do |f,v|
      self[f] = v if self&.send(f).blank?
    end
    self.save
  end
  
end