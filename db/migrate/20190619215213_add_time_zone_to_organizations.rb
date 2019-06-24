class AddTimeZoneToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :time_zone, :string, default: ""
  end
end
