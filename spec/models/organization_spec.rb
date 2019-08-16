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
end