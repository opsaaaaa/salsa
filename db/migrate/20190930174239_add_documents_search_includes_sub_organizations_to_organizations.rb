class AddDocumentsSearchIncludesSubOrganizationsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :document_search_includes_sub_organizations, :boolean, :null => false, default: false
  end
end
