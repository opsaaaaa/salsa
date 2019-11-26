class AddAllowExistingSalsasForNewCoursesToOrganizations < ActiveRecord::Migration[5.1]
  def change
    add_column :organizations, :allow_existing_salsas_for_new_courses, :boolean, default: false
  end
end
