
namespace :documents do
  
  # examples:
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_title'],[ data-dynamic='course.course_title']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-default='course_id'],[ data-dynamic='course.course_id']]"
  # rake "documents:change_html_attribute[org.example.com,2019_sp,[data-dynamic='course.course_title'],[data-default='course_title']]"

  desc "change an html attribute for all documents in an organizations time period"
  task :change_html_attribute, [:org_path, :period_slug, :target, :new_tag] => :environment do |t, args|
    org_slug = args[:org_path]
    period_slug = args[:period_slug]
    new_tag = args[:new_tag]
    target = args[:target]

    @org = Organization.find_by slug: org_slug

    period = get_period slug: period_slug    
    documents = Document.where organization: @org.self_and_descendants, period: period

    changed = 0
    STDOUT.puts [
      "    Change the #{target} attribute to #{new_tag}.",
      "    #{documents.count} could be changed. (yes/no)"
    ]

    input = STDIN.gets.strip
    if input.downcase == 'yes'
      puts input
      documents.each do |doc|
        changed += 1 if swap_attr document: doc, target: target, new_tag: new_tag
      end
    end
    
    STDOUT.puts "    #{changed}/#{documents.count} documents have been changed"
  end

  def get_period slug: nil
    if slug.present?
      return Period.where organization: @org.root.self_and_descendants, slug: slug
    else
      return Period.where organization: @org.root.self_and_descendants, is_default: true
    end
  end

  def swap_attr document:, target:, new_tag:
    page = Nokogiri::HTML(document.payload)
    
    elements = page.css( target )
    old_elements = elements.to_s

    if elements.present?
      elements.each do |e|
        e.remove_attribute( attr_name css: target )
        e[attr_name css: new_tag] = attr_value css: new_tag
      end
    end

    document.payload = page.to_s

    old_elements.to_s != elements.to_s && document.save!
  end

  def attr_name css:
    css.match( /[\w(_|\-)]+/ ).to_s
  end

  def attr_value css:
    css.match( /(?<=('|")).*?(?=('|"))/ ).to_s
  end

end



