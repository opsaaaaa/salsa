Feature: CRUD Users
as a organization_admin
In order to manage my organization's users
I want to create, edit, and view users

  Background:
    Given there is a organization
    And that I am logged in as a admin on the organization
    And I am on the users index page for the organization

  Scenario: View all of the users
    Given there are 5 users on the organization
    And I am on the users index page for the organization
    Then I should be able to see all the users

  Scenario: Create User
     When I click the "New" link
     And I fill in the user form with:
        | name | John Doe |
        | email | johndoe@test.com |
        | password | secret |
     And I click on "Create User"
     Then I should see "User was successfully created."

  Scenario: Update User
     Given there is a User
     And I click the "Edit" link
     And I fill in the user form with:
        | name | John Doe |
        | email | johndoe@test.com |
        | password | secret |
     And I click on "Update User"
     Then I should see "User was successfully updated."
