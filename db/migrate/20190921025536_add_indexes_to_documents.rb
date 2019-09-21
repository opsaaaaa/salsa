class AddIndexesToDocuments < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :documents, :users
    add_foreign_key :documents, :periods
    add_foreign_key :documents, :workflow_steps
    add_foreign_key :documents, :components

    add_index :documents, :component_version
    add_index :documents, :lms_published_at
    add_index :documents, :published_at
    add_index :documents, :created_at
    add_index :documents, :updated_at
    add_index :documents, :remote_identifier
  end
end
