class WorkflowLog < ApplicationRecord
  belongs_to :document
  belongs_to :organization
  belongs_to :user
  belongs_to :step, class_name: WorkflowStep
end
