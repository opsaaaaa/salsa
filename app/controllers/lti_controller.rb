require 'ims/lti'
require 'uri'

class LtiController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_if_user_archived
    before_action :x_frame_allow_all
    before_action :lms_connection_information

    def init
        # raise session[:saml_authenticated_user]["id"].to_s.downcase.inspect
        # raise UserAssignment.find_by("lower(username) = ?", session[:saml_authenticated_user]["id"].to_s.downcase)&.user.inspect
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
                    email: params['tool_consumer_instance_contact_email']
                }


                session['institution'] = request.env['SERVER_NAME']
                session[:saml_authenticated_user] = {}
                session[:saml_authenticated_user]['id'] = params['user_id']
                # raise session[:saml_authenticated_user]["id"].to_s.downcase.inspect


                # logout any current user
                session[:authenticated_user] = false
                user = current_user

                if user
                    # login the new user
                    session[:authenticated_user] = user.id
                else # when the LTI user id dose not match a remote_user_id
                    test1 = 1
                    user = User.all.where(email: lti_info[:email])
                    # and the LTI email matches only one users email
                    if user.count == 1
                        test1 = 2
                        user = user.first
                        # if user.user_assignments.count == 1
                        # raise user.user_assignments.inspect
                        # org_roles = @organization.user_assignments.pluck()
                        # if user.orga.pluck(:id).map.include?(@organization.users.pluck(:id))
                        #     test1 = 3
                            
                        # end
                        
                        # raise @organization.self_and_descendants.pluck(:id).inspect
                        # raise user.user_assignments.pluck(:organization_id).inspect
                        # raise ((@organization.self_and_descendants.collect {|org| org.user_assignments.pluck(:id)}).flatten & user.user_assignments.pluck(:id)).inspect
                        
                        # and that users role has an organization that is within LTI organization (self and descendants)
                        # and that user has only one role within the LTI organization (self and descendants)
                        if ((@organization.self_and_descendants.collect {|org| org.user_assignments.pluck(:id)}).flatten & user.user_assignments.pluck(:id)).count == 1
                            test1 = 4
                            # user = User.find_by(name: "cow")

                            # and that user dose not have global permissions.
                            if !user.user_assignments.pluck(:organization_id).map.include?(nil)
                            
                                test1 = 5
                                # and remote_use_id is empty
                                # ua = user.user_assignments.first
                                # ua.username = nil
                                # ua.save
                                test1 = user.user_assignments.first.username.to_s + "_fail"
                                # raise ([nil] & [nil, '']).inspect
                                if !([user.user_assignments.first.username] & [nil, ""]).empty?
                                # if !nil.nil? && !"".empty?
                                    test1 = user.user_assignments.first.username.to_s + "_pass"
                                    # then populate the remote_user_id for that user with LTI user id
                                    # and login that user.
                                    ua = user.user_assignments.first
                                    ua.username = lti_info[:login_id]
                                    ua.save
                                end
                            end
                        end

                        # raise ([ 1, 2, 3, 4, 5, 6, 7] & [13 , 20, 10]).empty?.inspect
                        
                        # if !(@organization.self_and_descendants.pluck(:id) & user.user_assignments.pluck(:organization_id)).empty?
                        #     # test1 = 4
                        #     # raise 
                        #     if true
                        #     end
                        # end
                    end
                    raise test1.to_s
                    # test = get_items_with_empty_feild(username:  @organization.user_assignments)
                    # Organization.empty_remote_user_ids
                    # User.empty_remote_user_ids                    
                    # UserAssignments.empty_remote_user_ids

                    # # input should be an array and a field
                    # with_empty_feilds(username:  @organization.user_assignments )
                    # returns an array of records with :field that is blank
                    
                    # user_potato = User.all.where()
                    # potato2 = @organization.self_and_descendants.all.collect {|org| org.user_assignments.where({username: [nil,""]})&.user}
                    # org_users = @organization.self_and_descendants.collect {|org| org.users }
                    # potato2 = org_users.collect {|user| user&.user_assignments }
                    # [1].user_assignments
                    # potato3 = potato2.all

                    # get_all_users = []
                    # @organization.self_and_descendants.each do |org|
                        # result.push(items.where({feild => [nil,""]})
                        # get_all_users.push(org.users)
                    # end 
                    # test1 = [[1,2],[3,[2,5]]]
                    # org_ids = @organization.self_and_descendants.pluck(:id)
                    # user_by_email = User.all.where(email: lti_info[:email] )
                    # if user_by_email && user_by_email.count == 1
                        # user_by_email = user_by_email.first


                    # end
                    # test3 = test2.flatten(1).where({ username: [nil,""], email: lti_info[:email] })
                    # raise user_by_email.inspect
                    # raise get_all_users.where({ username: [nil,""], email: lti_info[:email] })
                    # raise get_all_users.inspect
                    # org_user = org_users.where({username: [nil,""], email: lti_info[email]})
                    
                    # test1 = users.where lti_info[:email]
                    # test = User.all.where({username: [nil,""], email: lti_info[email]})
                    # raise @organization.self_and_descendants.inspect
                    # raise users.inspect
                    # raise User.find_by(name: "cow").user_assignments.first.inspect
                    # raise User.first.user_assignments.count.inspect
                end
                # raise current_user.inspect

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
                # render :json => params
                render :json => params
            end
        else
            raise 'invalid lti request'
        end
    end

    private

    def remote_user_id_role_blacklist
        ["admin"]
    end

    def get_items_with_empty_feild (val)
        result = []
        val.each do |feild, items|
            result.push(items.where({feild => [nil,""]}))
        end
        return nil if result.blank?
        return result
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