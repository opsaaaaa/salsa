class AddForignKeyToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :organizations, :organizations, column: :parent_id
  end
end
