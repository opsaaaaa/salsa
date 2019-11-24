module DocumentsHelper

  def edit_document_or_lms_course_path( condition: params[:lms_course_id] ,**path_args) 
    if condition
        path_args.delete(:id) 
        return lms_course_document_path( path_args )
    else
        path_args.delete(:lms_course_id)
        return edit_document_path( path_args )
    end
  end

  def existing_document?
    @has_existing_document ||= @existing_document && !@existing_document&.same_record_as?(@document)
  end

end