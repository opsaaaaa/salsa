require 'rails_helper'

RSpec.describe "lti init", type: :request do
    let(:org) { FactoryBot.create(:organization, 
        slug: root_url.gsub(/(http|:|\/)/,""),
        lms_authentication_source: 'LTI', 
        lms_authentication_id: '111111111111', 
        lms_authentication_key: 'issomething'
    ) }
    let(:sub_org) { FactoryBot.create(:sub_organization, parent_id: org.id) }
    let(:doc) { FactoryBot.create(:document, organization_id: org.id, lms_course_id: "lti_course_id") }
    let(:sub_doc) { FactoryBot.create(:document, organization_id: sub_org.id, lms_course_id: "sub_lti_course_id") }
    let(:request_params) {{
        oauth_consumer_key: org.lms_authentication_id,
        method: "POST",
        oauth_timestamp: Time.now.utc.to_i,
        launch_presentation_return_url: "https://www.example.com",
        roles: 'urn:lti:role:ims/lis/Instructor',
        context_label: doc.lms_course_id
    }}
    
    context "request" do
        it "error invalid notice when requests are more than 15 minutes old" do
            expect {
                post lti_init_path(org_path: org.full_slug), params: request_params.merge({oauth_timestamp: 100.minutes.ago.to_time.to_i})
            }.to raise_error(RuntimeError, /invalid nonce/)
        end

        it "finds a document by course id" do
            post lti_init_path(org_path: org.full_slug), params: request_params
            expect(response).to redirect_to lms_course_document_path(doc.lms_course_id)
        end

        it "finds no document" do
            $stdout.puts request_params.except(:role, :context_label)
            post lti_init_path(org_path: org.full_slug), params: request_params.except(:roles, :context_label)
            expect(response.status).not_to eql 200
        end
        
        it "finds a doucment by view id" do
            post lti_init_path(org_path: org.full_slug), params: request_params.except(:roles)
            expect(response).to redirect_to document_path( doc.view_id)
        end
        
        it "finds a sub org document" do
            post lti_init_path(org_path: sub_org.full_slug), params: request_params.merge({context_label: sub_doc.lms_course_id}).except(:roles)
            expect(response).to redirect_to document_path( sub_doc.view_id)
        end

        it "find by lms_course_id dose not excape the organization"
    end

    context "login existing user" do  

        it "is aborted when the user has a global role"

        it "works with sub organizations"
        
        it "dose not excape the organization"
    end

    context "login new user" do 
        let(:user_params) { {
            lis_person_sourcedid: "ltisourseid" 
        } }
        it "by lis_person_sourcedid" do
            expect(UserAssignment.find_by(username: user_params[:lis_person_sourcedid])&.user.present?).to eq(false)
            post lti_init_path(org_path: org.full_slug), params: request_params.merge(user_params)
            expect(UserAssignment.find_by(username: user_params[:lis_person_sourcedid])&.user.present?).to eq(true)
        end

        it "by user_id"
    end

end
