require 'rails_helper'
require 'date'
require 'organization'

RSpec.describe ApplicationHelper, type: :helper do

  context 'formatted_date' do
    let(:utc_org) { FactoryBot.create(:organization, time_zone: "UTC") }
    let(:sub_org) { FactoryBot.create(:organization, parent_id: utc_org.id) }
    let(:idlw_org) { FactoryBot.create(:organization, time_zone: 'International Date Line West') }
    let(:date) { Time.current.midnight }

    it 'should cascade' do
      utc_org_date = formatted_date(date, utc_org.id)
      sub_org_date = formatted_date(date, sub_org.id)
      expect(utc_org_date).to eq(sub_org_date)
    end

    it 'should handle time_zones' do
      idlw_org_date = formatted_date(date, idlw_org.id)
      utc_org_date = formatted_date(date, utc_org.id)
      expect(idlw_org_date != utc_org_date).to eq(true)
    end
    
  end
end
