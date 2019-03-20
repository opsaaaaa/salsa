class AddChildrenCountToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :children_count, :integer, :null => false, :default => 0
  end
end
