

$(function(){
    
    $('a.course_select_links').click(function (event){
        event.preventDefault();
        
        form = $('#lms_course_id_select_form');
        form.attr("href", $(this).attr("href"));
        console.log(form.attr("href"));
    });

});
