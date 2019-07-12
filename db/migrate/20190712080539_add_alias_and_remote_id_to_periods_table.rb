class AddAliasAndRemoteIdToPeriodsTable < ActiveRecord::Migration[5.0]
  def change
      add_column :periods, :alias, :string, :null => true
      add_column :periods, :remote_id, :string, :null => true
  end
end
