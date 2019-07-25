class AddReportsIncludeLmsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :reports_include_lms, :boolean, :null => false, default: false
  end
end
