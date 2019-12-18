namespace :documents do
  
  # examples:
  # rake "documents:remove_html[org.example.com,2019_sp,a#print_link]"

  desc "add html to all documents in an organizations time period"
  task :add_html, [:org_path, :period_slug, :target, :new_html, :as] => :environment do |t, args|
    target = args[:target]
    as = args[:as]&.to_sym || :child

    documents = get_documents args[:org_path], args[:period_slug]

    changed = 0
    respond_to_yes( ["    Add html elements matching: #{target}","    #{documents.count} documents could be changed. (yes/no)" ] ) do
      changed = change_all( documents ) {|doc| add_elements document: doc, target: target, new_html: args[:new_html], as: as }  
    end
    
    msg_documents_changed changed, documents.count
    # say "    #{changed}/#{documents.count} documents have been changed"
  end

end