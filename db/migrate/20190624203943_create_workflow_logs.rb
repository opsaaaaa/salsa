class CreateWorkflowLogs < ActiveRecord::Migration[5.1]
  def change
    create_table :workflow_logs do |t|
      t.belongs_to :document
      t.belongs_to :user
      t.belongs_to :step
      t.string :role
      t.timestamps
    end
  end
end
