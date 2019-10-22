require 'rails_helper'
require 'pp'

RSpec.describe Organization, type: :model do
  
  context "validation tests" do
    let(:organization) { FactoryBot.build(:organization) }

    it "factorybot build should save" do
      expect(organization.save).to eq(true)
    end

    it "ensure organization.id is not nil" do
      organization.save
      expect(organization.id != nil)
    end

    it 'ensure name presence' do
      organization.name = nil
      expect(organization.save).to eq(false)
    end

    it 'ensure slug presence' do
      organization.slug = nil
      expect(organization.save).to eq(false)
    end

    it 'ensure slug valid' do
      organization.slug = "/#@{=/(:;.!"
      expect(organization.save).to eq(false)
    end
  
  end
  
  context "setting method" do
    let(:settings) {{
      "lms_authentication_key" => "rspeclmsauthkeytest",
      "time_zone" => "utc+100",
      "lms_authentication_source" => nil,
      "lms_authentication_id" => "",
      "skip_lms_publish" => nil,
      "document_search_includes_sub_organizations" => true,
      "track_meta_info_from_document" => false
    }}
    let(:bool_setting) { {key:"hi"} }
    let(:org) { FactoryBot.create(:organization, settings) }
    let(:sub_org) { FactoryBot.create(:sub_organization, parent_id: org.id, lms_authentication_id: "") }

    it "FactoryBot should be correct" do
      org.save
      sub_org.save
      expect( Organization.find_by(settings).present?).to eq(true)
      expect( sub_org.root).to eq(org)
    end

    it ".setting should return correct values" do
      settings.each do |k,v|
        expect(org.setting(k.to_s)).to eq(v)
      end
    end
    
    it ".setting should inherit values from the root org" do
      settings.each do |k,v|
        if sub_org[k].nil? 
          expect(sub_org.setting(k.to_s)).to eq(v)
        else
          expect(sub_org.setting(k.to_s)).to eq(sub_org[k])
        end
      end
    end

    it ".root_org_setting should return the root orgs values" do
      settings.each do |k,v|
        expect(sub_org.root_org_setting(k.to_s)).to eq(v)
        expect(org.root_org_setting(k.to_s)).to eq(v)
      end
    end

  end
end    