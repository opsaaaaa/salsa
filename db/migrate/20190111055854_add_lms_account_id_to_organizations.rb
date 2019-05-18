class AddLmsAccountIdToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :lms_account_id, :string, :null => true
  end
end
