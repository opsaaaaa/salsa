class AddReportsIncludeLmsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :reports_use_document_meta, :boolean, :null => false, default: false
  end
end
