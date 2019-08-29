
module Populate
  extend ActiveSupport::Concern
  
  def populate(fills)
    fills.each do |f,v|
      self.send("#{f.to_s}=",v) if self&.send(f).blank?
    end
    self.save
  end
  
  # def set(values)
  #   values.each do |feild, val|
  #     self[feild] = val
  #   end
  #   self.save
  # end
        
end