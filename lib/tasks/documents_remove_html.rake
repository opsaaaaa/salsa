
require 'task_helper'
require 'documents_task_helper'

namespace :documents do
  
  # examples:
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_title']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_id']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-dynamic='course.course_title']]"

  desc "remove html from all documents in an organizations time period"
  task :remove_html, [:org_path, :period_slug, :target] => :environment do |t, args|
    target = args[:target]

    documents = get_documents args[:org_path], args[:period_slug]

    changed = 0
    respond_to( ["    Remove all elements matching: #{target}","    #{documents.count} documents could be changed. (yes/no)" ] ) do |awnser|
      if awnser.downcase == 'yes' || awnser.downcase == 'y'
        changed = change_all( documents ) {|doc| remove_elements document: doc, target: target }  
      end
    end
    
    say "    #{changed}/#{documents.count} documents have been changed"
  end

end