Feature: workflow approver
As a supervisor
in order to add my staff into salsa
I want to import users into the database


  Scenario: import_users
    Given there is a organization
    And that I am logged in as a supervisor
    And I am on the show page for the organization
     When I click the "Add Component" link
     And I fill in the component form with:
        | name | Step 1 |
        | slug | step_1 |
        | description | this is a description |
        | category | document |
        | layout | <head></head> |
        | format | html |
     And I click on "Create Component"
     Then I should see "Component was successfully created."
  Scenario: import_users
    When I click the  link
    Then I should receive the report file
    And the Report zip file should have documents in it
