namespace :documents do
  
  # examples:
  # rake "documents:remove_html[org.example.com,2019_sp,a#print_link]"

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