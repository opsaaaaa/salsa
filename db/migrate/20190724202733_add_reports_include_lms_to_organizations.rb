class AddReportsIncludeLmsToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :reports_include_lms, :string, default: "false"
  end
end
