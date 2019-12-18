
module DocumentsTaskHelper
  require 'task_helper'
  include TaskHelper
  
  def attr_name css:
    css.match( /[\w(_|\-)]+/ ).to_s
  end

  def attr_value css:
    css.match( /(?<=('|")).*?(?=('|"))/ ).to_s
  end

  def change_all arr, &block
    changed = 0
    arr.each do |obj|
      changed += 1 if block.call obj
    end
    changed
  end

  def swap_attr document:, target:, new_tag:
    document.change_html do |page|
      elements = page.css( target )

      if elements.present?
        elements.each do |e|
          e.remove_attribute( attr_name css: target )
          e[attr_name css: new_tag] = attr_value css: new_tag
        end
      end
    end
  end

  def get_documents org_path, period_slug
    org = find_org slug: org_path
    period = Period.find_by slug: period_slug, organization: org.self_and_ancestors

    Document.where organization: org.self_and_descendants, period: period
  end

  def remove_elements document:, target:
    document.change_html do |page|
      elements = page.css( target )
      elements.each {|e| e.remove } if elements.present?
    end
  end

  def add_elements document:, target:, new_html:, as: :child, &condition
    condition ||= Proc.new {|page ,targ, new, atr| (atr['id'].blank? || page.css( "##{atr['id']}").blank?) && targ.count == 1}
    new_elements = Nokogiri::HTML.fragment( new_html )
    new_id = new_elements.css(':root')[0].attribute('id')
    document.change_html do |page|
      element = page.css( target )
      if condition.call page, element, new_elements, new_elements.css(':root')[0].attributes
        case as
        when :child
          element.each {|e| e.add_child(new_elements) }
        when :next
          element.each {|e| e.add_next_sibling(new_elements) }
        when :previous
          element.each {|e| e.add_previous_sibling(new_elements) }
        end
      end
    end
  end

end