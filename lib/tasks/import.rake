
require 'csv'    
require 'json'
require 'pathname'
# require 'organization'
require 'fileutils'

namespace :parse do
  desc "imports data from a csv file into a json file"
  task :csv, [:csv_dir, :json_dir, :force] do |task,args|

    force = args[:force] || force = false
    json_dir = args[:json] || json_dir = "/tmp/data/csv/"
    csv_dir = args[:csv] || csv_dir = "/storage/csv/"
    
    csv_dir = Rails.root.to_s + csv_dir
    json_dir = Rails.root.to_s + json_dir

    FileUtils.mkdir_p json_dir, :mode => 0777
    FileUtils.mkdir_p csv_dir, :mode => 0777

    csv_file_paths = Dir[csv_dir + "*.csv"]

    csv_file_paths.each do |path|
      file_name = Pathname.new(path).basename.to_s.split(".")[0]
      json_path = "#{json_dir}#{file_name}.json"

      if File.file?(json_path) && !force
        puts "#{json_path} exists already."
      else
        data = []
        csv_text = File.read(path)
        csv = CSV.parse(csv_text, :headers => true).by_row
        headers = csv.headers
        csv.each {|row| data << Hash[row] }

        # puts rows.select {|r| r['username'].nil? }
        File.open("#{json_dir}#{file_name}.json","w+") do |f|
          f.write(data.to_json)
        end
      end
    end
  end
end


namespace :change do
  namespace :users do
    desc "updates the user from the old batch_uid"
    task :batch_uid, [:org_slug, :json_path] => [:environment, "parse:csv"] do |task,args|
      
      json_path = args[:json_path] 
      json_path = Rails.root.to_s + json_path
      org_slug = args[:org_slug]
      users_saved = []
      assignments_saved = []

      if org_slug && json_path
        @org = Organization.find_by slug: org_slug

        data = JSON.parse File.read(json_path)
        user_data = Hash[ data.select {|d| !d['username'].nil? && !d['batch_uid'].nil?}.map {|d| [d['batch_uid'],{'username'=>d['username'],'eamil'=>d['email']}]} ]
        
        assignments = UserAssignment.where organization_id: @org.self_and_descendants, username: user_data.keys
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
      else
        puts "you didn't provide a slug and json file path"
        puts "rake '#{task}[<org_slug>,<json_file_path>]'"
      end
    end
  
  end

end

