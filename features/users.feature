Feature: CRUD Users
as a organization_admin
In order to manage my organization's users
I want to create, edit, and view users

  Background:
    Given there is a organization
    And that I am logged in as a admin on the organization
    And I am on the users index page for the organization

  Scenario: View all of the users
    Given there are 5 users for the organization
    And I am on the users index page for the organization
    Then I should be able to see all the periods for the organization

  Scenario: Create User
     When I click the "Add User" link
     And I fill in the user form with:
        | name | John Doe |
        | email | johndoe@test.com |
        | password | secret |
     And I click on "Create User"
     Then I should see "User successfully created."

  Scenario: Update User
     Given there is a user on the organization
     And I am on the users index page for the organization
     And I save the page
     And I click the "#show_user" link
     And I click the "Edit User" link
     And I fill in the user form with:
        | name | John Doe |
        | email | johndoe@test.com |
        | password | secret |
     And I click on "Update User"
     And I save the page
     Then I should see "User successfully updated."
