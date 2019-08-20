class AddUsedDucomentMetaToReportArchive < ActiveRecord::Migration[5.1]
  def change
    add_column :report_archives, :used_document_meta, :boolean, default: :true
  end
end
