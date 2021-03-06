namespace :documents do
  
  # examples:
  # rake 'documents:add_html[org.example.com,2019_sp,section#H,<a href target="_blank" id="print_link">print</a>,previous]'

  desc "add html to all documents in an organizations time period"
  task :add_html, [:org_path, :period_slug, :target, :new_html, :as] => :environment do |t, args|
    target = args[:target]
    new_html = args[:new_html]
    as = args[:as]&.to_sym || :child

    documents = get_documents args[:org_path], args[:period_slug]

    changed = 0
    respond_to_yes( ["    Add '#{new_html}'", "    to one element matching '#{target}' as the #{as.to_s} element.","    #{documents.count} documents could be changed. (yes/no)" ] ) do
      changed = change_all( documents ) {|doc| add_elements document: doc, target: target, new_html: args[:new_html], as: as }  
    end
    
    msg_documents_changed changed, documents.count
  end

end