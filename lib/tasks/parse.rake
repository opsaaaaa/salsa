
require 'csv'    
require 'json'
require 'pathname'
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
