require 'task_helper'

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