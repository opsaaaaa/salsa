Feature: workflow approver
As a supervisor or organization_admin
in order to add my staff into salsa
I want to import users into the database


  Scenario: import_users
    Given there is a organization
    And the organization enable_workflows option is enabled
    And that I am logged in as a supervisor on the organization
    And I am on the organization show page
    When I click the "Import Users" link
    And I fill in the users form with:
      | emails | user@test.com, anotheruser@test.com |
    And I click on "Create Users"
    Then I should see "2 Users created successfully"

  Scenario: import_users
    Given there is a organization
    And that I am logged in as a organization_admin on the organization
    And I am on the organization show page
    When I click the "Import Users" link
    And I fill in the users form with:
      | emails | user@test.com, anotheruser@test.com |
    And I click on "Create Users"
    Then I should see "2 Users created successfully"
