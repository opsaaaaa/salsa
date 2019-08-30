class AddNameReportsByToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :name_reports_by, :string
  end
end
