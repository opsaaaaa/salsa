Feature: lms_course_select
As a designer i want to have a dialog for creating a new salsa 

  # ./cucumber.sh features/lms_course_select.feature

  Background: 
    Given there is a organization
    And that I am logged in as a admin

  Scenario: visit my document course with matching document_token
    Given the "organization" has a "document"
    And the "document" has:
      | lms_course_id | an_existing_lms_course_id |
      | view_id | a_matching_token |
    And i visit the course page with:
      | lms_course_id | an_existing_lms_course_id |
      | document_token | a_matching_token |
    Then I should see "My SALSA"
    And I should not see "select" in the url
  
  Scenario: use my SALSA as a template 
    Given the "organization" has a "document"
    And the "document" has:
      | lms_course_id | an_existing_lms_course_id |
      | view_id | a_matching_token |
      | payload | <p>the existing document content</p> |
    And i visit the course page with:
      | lms_course_id | a_new_lms_course_id |
      | document_token | a_matching_token |
    Then I should see "select" in the url
    When I click on "Use the SALSA as a template"
    Then I should see "the existing document content"
    And an "document" should be present with:
      | name | a_new_lms_course_id |

  Scenario: template with a token that matches a diffrent document
    Given the "organization" has a "course_document"
    Given the "organization" has a "token_document"
    And the "course_document" has:
      | lms_course_id | the_lms_course_id |
      | payload | <p>an empty syllabus</p> |
    And the "token_document" has:
      | view_id | the_token |
      | payload | <p>my imported syllabus content</p> |
    And i visit the course page with:
      | lms_course_id | the_lms_course_id |
      | document_token | the_token |
    Then I should see "select" in the url
    When I click on "Use the SALSA as a template"
    Then I should see "the_lms_course_id" in the url
    Then I should see "my imported syllabus content"
    Then an "document" should be present with:
      | lms_course_id | the_lms_course_id |
      | payload | <p>my imported syllabus content</p> |
