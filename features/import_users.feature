Feature: workflow approver
As a supervisor
in order to add my staff into salsa
I want to import users into the database


  Scenario: import_users
    Given there is a organization
    And that I am logged in as a supervisor
    And I am on the show page for the organization
    When I click the "Import Users" link
    And I fill in the import_users form with:
      | emails | user@test.com, anotheruser@test.com |
    And I click on "Create Users"
    Then I should see "2 Users Imported successfully."
