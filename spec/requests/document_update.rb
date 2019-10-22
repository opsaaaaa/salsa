require 'factory_bot'
require 'rails_helper'

RSpec.describe "Doucment Update", type: :request do
    let(:org) { FactoryBot.create(:organization, slug: root_url.gsub(/(http|:|\/)/,""), track_meta_info_from_document: true, lms_authentication_id: "3013371946") }
    let(:sub_org) { FactoryBot.create(:sub_organization, parent_id: org.id) }
    let(:doc) { FactoryBot.create(:document, organization_id: org.id, lms_course_id: "rspec_test_meta_course_root_org") }
    let(:sub_doc) { FactoryBot.create(:document, organization_id: sub_org.id, lms_course_id: "rspec_test_meta_course_sub_org") }
    let(:request_params) {{
        meta_data_from_doc:{
            "0"=>{
                root_organization_slug: org.slug
            }
        },
        format: "json",
        method: "PATCH"
    }}

    it 'tracks document meta for a root organization' do
        test_meta = {value: "the value of the test meta for a root organization", key: "rspec_test_meta_key_root_org" }
        request_params[:meta_data_from_doc]["0"] = request_params[:meta_data_from_doc]["0"].merge(test_meta)
        patch "#{document_path(id: doc.edit_id, org_path: org.full_slug, publish: true, document_version: doc.versions.count)}", params: request_params
        expect(DocumentMeta.where("key like ? and document_id = ? and value = ?", "salsa_#{test_meta[:key]}%", doc.id, test_meta[:value]).present?).to eq(true)
    end

    it 'tracks document meta for a sub organization' do
        $stdout.puts sub_org.parent.slug.inspect
        test_meta = {value: "the value of the test meta for a sub organization", key: "rspec_test_meta_key_sub_org" }
        request_params[:meta_data_from_doc]["0"] = request_params[:meta_data_from_doc]["0"].merge(test_meta)
        patch "#{document_path(id: sub_doc.edit_id, org_path: sub_org.full_slug, publish: true, document_version: sub_doc.versions.count)}", params: request_params
        expect(DocumentMeta.where("key like ? and document_id = ? and value = ?", "salsa_#{test_meta[:key]}%", sub_doc.id, test_meta[:value]).present?).to eq(true)
    end
    
end