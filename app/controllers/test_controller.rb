class TestController < ApplicationController
    before_action :require_admin_permissions

    def email
        user = User.find params[:organization_user_id]

        UserMailer.send_test(user.email, 'test')
        redirect_back(fallback_location: organizations_path)
    end
end
