class TestController < ApplicationController
    before_action :require_admin_permissions

    def email
        user = User.find params[:organization_user_id]

        TestMailer.send_test(user.email, 'test').deliver_later
        flash[:notice] = "Sent email to #{user.email}"
        
        redirect_back(fallback_location: organizations_path)
    end
end
