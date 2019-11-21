   
require 'json'

namespace :map do
  namespace :users do
    desc "updates the users with data from a csv file"
    task :batch_uid, [:org_slug, :json_path] => [:environment] do |task,args|
      
      map_task_head args do |data, org|
        users_saved = []
        assignments_saved = []
      
        user_data = Hash[ data.map {|d| [d['batch_uid'],{'username'=>d['username'],'eamil'=>d['email']}]} ]
        
        assignments = UserAssignment.where organization_id: org.self_and_descendants, username: user_data.keys
        users = User.where id: assignments.pluck(:user_id), name: user_data.keys

        users.each do |user| 
          values = user_data[user.name]
          user.name = values['username']
          if values['email']
            user.email = values['email']
          else
            user.email = "#{values['username']}@example.com"
          end
          users_saved << user.save!
        end

        assignments.each do |a|
          un = user_data[a.username]['username']
          a.username = un
          assignments_saved << a.save!
        end
      
        puts "Atempted to update #{users_saved.count} users. #{users_saved.select {|t| t }.count} save successfuly."
        puts "Atempted to update #{assignments_saved.count} assigments. #{assignments_saved.select {|t| t }.count} save successfuly."
      end
    end
  end

  namespace :documents do 
    desc "update the documents with data from a csv file"
    task :user_id, [:org_slug, :json_path] => [:environment] do |task,args|
 
      map_task_head args do |data, org|
        documents_saved = []
        
        course_map = Hash[ data.collect {|d| [d['username'],d['lms_course_id']] } ]
        assignments = UserAssignment.where organization_id: org.self_and_descendants, username: data.collect {|d| d['username']}
        document_map = Hash[ assignments.map {|a| [course_map[a.username], a.user_id] }]
        
        documents = Document.where organization_id: org.self_and_descendants, lms_course_id: data.collect {|d| d['lms_course_id']}
        
        documents.each do |doc|
          doc.user_id = document_map[doc.lms_course_id] 
          documents_saved << doc.save!
        end

        puts "Atempted to update #{documents_saved.count} documents. #{documents_saved.select {|t| t }.count} save successfuly."
      end
    end
  end

  def map_task_head args
    if args[:json_path] && args[:org_slug]
      
      yield get_json_data( args[:json_path]), get_org( args[:org_slug])

    else
      puts "you didn't provide a slug and json file path"
      puts "rake '#{task}[<org_slug>,<json_file_path>]'"
    end
  end

  def get_json_data json_path
    @data ||= JSON.parse( File.read(Rails.root.to_s + json_path) ).select {|d| !d['username'].nil? && !d['batch_uid'].nil?}
  end

  def get_org slug
    @org ||= Organization.find_by slug: slug
  end

end

