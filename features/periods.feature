Feature: CRUD Periods
as a organization_admin
In order to sort my organization's documents
I want to create, edit, and view periods

  Background:
    Given there is a organization
    And that I am logged in as a admin on the organization
    And I am on the periods index page for the organization

  Scenario: View all of the periods
    Given there are 5 periods for the organization
    And I am on the periods index page for the organization
    Then I should be able to see all the periods for the organization

  Scenario: Create Period
     When I click the "New" link
     And I save the page
     And I fill in the period form with:
        | name | spring 2019 |
        | slug | spring-2019 |
        | duration | 90 |
     And I click on "Create Period"
     Then I should see "Period was successfully created."

  Scenario: Update Period
     Given there is a period on the organization
     And I am on the periods index page for the organization
     And I click the "Edit" link
     And I fill in the period form with:
        | name | spring 2019 |
        | slug | spring-2019 |
        | duration | 90 |
     And I click on "Update Period"
     Then I should see "Period was successfully updated."
