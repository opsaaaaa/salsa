Feature: workflow steps direct supervisor
as a direct supervisor
In order to do employee review
I want to have a defined set of workflow steps to go thrugh

  Background:
    Given there is a organization
    And the organization enable_workflows option is enabled
    And that I am logged in as a supervisor on the organization

  @javascript
  Scenario: fail to complete step_1
    Given there is a workflow
    And there is a user with the role of staff
    And I am the supervisor of the user
    And there is a document on the first step in the workflow and assigned to the user
    And I am on the "/workflow/documents" page
    Then I should not see "#edit_document"
    When I go to the document edit page for the users document
    Then I should see "you are not authorized to edit that document"

  @javascript
  Scenario: fail to complete final_step
    Given there is a workflow
    And there is a document on the last step in the workflow and assigned to the current user
    And I am on the "/workflow/documents" page
    Then I should not see "#edit_document"
    When I go to the document edit page for the users document
    And I click the "#tb_share" link
    Then I should see "You are not authorized to edit this document"
