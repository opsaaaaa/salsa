class TestController < ApplicationController
    before_action :require_admin_permissions

    def email
        user = User.find params[:organization_user_id]

        test=TestMailer.test_email(user.email, 'test').deliver_now
        flash[:notice] = "Sent email to #{user.email} - #{test}"

        redirect_back(fallback_location: organizations_path)
    end
end
