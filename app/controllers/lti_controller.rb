require 'ims/lti'
require 'uri'

class LtiController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :x_frame_allow_all

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
                redirect_to params[:launch_presentation_return_url] + '&' + URI.encode_www_form_component("The floor's on fire... see... *&* the chair.")
            else
                render :json => params
            end
        else
            raise 'invalid lti request'
        end


    end

    private

    def x_frame_allow_all
        response.headers["X-FRAME-OPTIONS"] = "ALLOWALL"
    end

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
        # TODO: move to organization settings

        temp_secrets = {}
        temp_secrets['3bd076ef7e0439b821ff42b9e663bbae'] = '37d1a559ef511347fcad05f88d795c30'
        secret = nil

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
