
require 'rails_helper'
require 'date'
require 'organization'

RSpec.describe TimeZoneHelper, type: :helper do

  context 'formatted_date' do
    let(:date) { Time.current.midnight }

    it 'should handle time_zones' do
      idlw_org_date = formatted_date(date, time_zone: 'International Date Line West')
      utc_org_date = formatted_date(date, time_zone: "UTC")
      expect(idlw_org_date != utc_org_date).to eq(true)
    end
    
  end
end
