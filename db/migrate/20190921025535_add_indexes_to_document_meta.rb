class AddIndexesToDocumentMeta < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :document_meta, :documents
    add_index :document_meta, :lms_course_id
    add_index :document_meta, :key
    add_index :document_meta, :root_organization_id
  end
end
