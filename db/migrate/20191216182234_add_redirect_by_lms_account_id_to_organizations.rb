class AddRedirectByLmsAccountIdToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :redirect_by_lms_account_id, :boolean, default: false
  end
end
