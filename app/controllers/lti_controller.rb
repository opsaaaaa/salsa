require 'ims/lti'
require 'uri'

class LtiController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_if_user_archived
    before_action :x_frame_allow_all
    before_action :lms_connection_information

    def init
        consumer_key = get_consumer_key params
        consumer_secret = get_consumer_secret consumer_key
        is_valid_nonce = validate_oauth_nonce params

        if !is_valid_nonce
            raise 'invalid nonce'
        end

        authenticator = IMS::LTI::Services::MessageAuthenticator.new(request.url, request.request_parameters, consumer_secret)

        if authenticator.valid_signature?
            if params[:launch_presentation_return_url]
                lti_info = {
                    course_title: params['context_title'],
                    course_id: params['context_label'],
                    login_id: params['user_id'],
                    roles: params['roles'],
                }

                session['institution'] = request.env['SERVER_NAME']
                session[:saml_authenticated_user] = {}
                session[:saml_authenticated_user]['id'] = params['user_id']

                # logout any current user
                session[:authenticated_user] = false
                user = current_user
                
                if user
                    # login the new user
                    session[:authenticated_user] = user.id
                end

                if lti_info[:roles].include? 'urn:lti:role:ims/lis/Instructor'
                    session[:lti_info] = lti_info

                    redirect_to lms_course_document_path(lti_info[:course_id])
                else
                    document = @organization.documents.find_by_lms_course_id lti_info[:course_id]

                    if document
                        redirect_to document_path(document[:view_id])
                    else
                        return render :file => "public/404.html", :status => :not_found, :layout => false
                    end
                end
            else
                render :json => params
            end
        else
            raise 'invalid lti request'
        end
    end

    private

    def get_consumer_key(obj)
        key = nil

        # check for key in request, if found, return it
        if obj[:oauth_consumer_key]
            key = obj[:oauth_consumer_key]
        else
            raise "consumer key not found"
        end

        return key
    end

    def get_consumer_secret key
        temp_secrets = {}
        is_lti = @organization.setting('lms_authentication_source') == 'LTI'
        secret = nil

        if is_lti
            temp_secrets[@organization.setting('lms_authentication_id')] = @organization.setting('lms_authentication_key')
        end

        # check for key in request, if found, return it
        if temp_secrets[key]
            secret = temp_secrets[key]
        else
            raise "consumer secret not found"
        end

        return secret
    end

    def validate_oauth_nonce obj
        nonce = obj[:oauth_nonce]
        timestamp = obj[:oauth_timestamp]
        time = Time.at(timestamp.to_i)

        # if timestamp is greater than timeframe, reject
        timeframe = 15.minutes
        if time < (Time.now - timeframe).utc
            return false
        end

        # TODO: store nonce for some timeframe, if nonce is found, reject

        return true
    end
end