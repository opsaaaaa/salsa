class AddRemoteIdentifierToDocuments < ActiveRecord::Migration[5.1]
  def change
    add_column :documents, :remote_identifier, :string, :null => true
  end
end
