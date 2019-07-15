class AddPeriodMetaKeyToOrganizationsTable < ActiveRecord::Migration[5.0]
  def change
      add_column :organizations, :period_meta_key, :string, :null => true
  end
end
