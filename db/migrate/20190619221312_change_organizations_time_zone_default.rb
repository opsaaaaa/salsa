class ChangeOrganizationsTimeZoneDefault < ActiveRecord::Migration[5.1]
  def change
    change_column_default :organizations, :time_zone, "UTC"
  end
end
