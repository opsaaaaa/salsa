require 'rails_helper'

RSpec.describe LtiController, type: :controller do

    # feature lti populate remote user id

    # given the LTI user id matches a remote user id
    # then login that user.

    # given the LTI user id dose not match a remote_user_id
    # and the LTI email matches a user
    # and that users role has an organization that is within LTI organization (self and descendants)
    # and that user has only one role within the LTI organization (self and descendants)
    # and that user dose not have global permissions.
    # and remote_use_id is empty
    # then populate the remote_user_id for that user with LTI user id
    # and login that user.

end
