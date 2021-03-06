namespace :documents do
  require 'documents_task_helper'
  include DocumentsTaskHelper
  
  # examples:
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_title'],[ data-dynamic='course.course_title']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_id'],[ data-dynamic='course.course_id']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-dynamic='course.course_title'],[data-default='course_title']]"

  desc "change an html attribute for all documents in an organizations time period"
  task :change_html_attribute, [:org_path, :period_slug, :target, :new_tag] => :environment do |t, args|
    new_tag = args[:new_tag]
    target = args[:target]

    documents = get_documents args[:org_path], args[:period_slug]

    changed = 0
    respond_to_yes( ["    Change the #{target} attribute to #{new_tag}.","    #{documents.count} documents could be changed. (yes/no)" ] ) do
      changed = change_all( documents ) {|doc| swap_attr document: doc, target: target, new_tag: new_tag }  
    end
    
    msg_documents_changed changed, documents.count
  end

end