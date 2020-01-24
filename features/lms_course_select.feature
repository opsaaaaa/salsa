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
    And i visit that documents course page with:
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
    And i visit that documents course page with:
      | lms_course_id | a_new_lms_course_id |
      | document_token | a_matching_token |
    Then I should see "select" in the url
    When I click on "Use the SALSA as a template"
    Then I should see "the existing document content"

  Scenario: i break the course select and get a new document instead.