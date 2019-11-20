//= require jquery
//= require jquery_ujs
//= require bootstrap
//= require methods
//= require organization

function get_lms_course_id(body) {
  var data_lms_course = body.find('[data-lms-course]').attr("data-lms-course");
  if (data_lms_course){
    return jQuery.parseJSON(data_lms_course).course_id;
  }
  return null;
}

function get_document_meta(body) {
  var page = $("#page", body.contents() );
  var lms_course_id = get_lms_course_id(body);
  var meta_data_from_doc = [];

  page.find('[data-meta]:not(:input)').each(function() {
    var key = "salsa_" + $(this).attr('data-meta');
    var value = $(this).text().replace(/\s+/mg, ' ');
    meta_data_from_doc.push({
      key: key,
      value: value,
      lms_course_id: lms_course_id,
      root_organization_slug: window.location.hostname
    });
  });

  page.find(':input:not([data-meta])').each(function() {
    var key = "salsa_" + $(this).attr("id");
    var value = $(this).val();
    meta_data_from_doc.push({
      key: key,
      value: value,
      lms_course_id: lms_course_id,
      root_organization_slug: window.location.hostname
    });
  });

  return meta_data_from_doc 
}

function post_document_meta(url, meta_data_from_doc){
  if (meta_data_from_doc && meta_data_from_doc.length > 0) {
    $.ajax({
      url: url,
      data: {
        meta_data_from_doc: meta_data_from_doc
      },
      dataType: "json",
      method: "PATCH"
    });
  }
}

function run_document_meta(settings, html) {
  var body = html.find('body');

  // add document version to the url
  var document_version = body.find('[data-document-version]').attr('data-document-version');
  var queryStringStart = settings.url.search(/\?/) < 0 ? '?' : '&';
  settings.url = settings.url + queryStringStart + 'document_version=' + document_version;
  settings.url = encodeURI(settings.url);
 
  // check if track meta is enabled
  var organizationConfig = html.find("[data-organization-config]").data("organization-config");
  if (organizationConfig && organizationConfig["track_meta_info_from_document"]) {
    // collect and post the document meta
    post_document_meta(settings.url, get_document_meta(body));
  }
}

function run_document_meta_in_iframe(settings){
  var iframe = $('iframe#republish_iframe');
  run_document_meta(settings, $('html', iframe.contents()))
}