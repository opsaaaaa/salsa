Feature: CRUD Organization
as a admin
In order to have a org structure
I want to create, edit and view organizations

  Background:
    Given there is a organization
    And that I am logged in as a admin
    And I am on the organization show page

  Scenario: View all of the organizations
    Given there are 5 organizations
    And I am on the organization index page
    Then I should be able to see all the organizations

  Scenario: create organization
     When I click the "Add Organization" link
     And I fill in the organization form with:
        | name | Test Organization |
        | slug | test_organization |
        | default_account_filter | {"account_filter":"WI19"} |
     And I click on "Create Organization"
     Then I should see "Organization was successfully created."

  Scenario: update organization
     Given there is a organizations
     And I am on the organization show page
     And I click the "Update Organization" link
     And debugger
     When I fill in the organization form with:
        | name | Test Update Organization |
        | slug | test_update_organization |
        | default_account_filter | {"account_filter":"SP18"} |
     And I click on "Update Organization"
     Then I should see "Organization was successfully updated."
