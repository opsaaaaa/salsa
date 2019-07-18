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
     Given I am on the organization new page
   #   Then there should be a "Add Organization" button
   #   When I click the "Add Organization" link
     And I fill in the organization form with:
        | name | TestOrganization |
        | slug | testorganization.com |
     And I click on "Create Organization"
   #   Then I should see "Organization was successfully created." 
     Then an organization with a name of TestOrganization should be present

  Scenario: create organization see error on invalid slug
     Given I am on the organization new page
   #   Given I am on the organization index page
   #   When I click the "Add Organization" link
     And I fill in the organization form with:
        | name | Test Organization |
        | slug | %$#^!@& SDF SDFH$^%#$^$ |
        | default_account_filter | {"account_filter":"WI19"} |
     And I click on "Create Organization"
     Then I should see "Slug is invalid"

  Scenario: update organization
     And I am on the organization show page
     And I click the "Settings" link
     When I fill in the organization form with:
        | name | Test Update Organization |
        | slug | localhost |
        | default_account_filter | {"account_filter":"SP18"} |
     And I click on "Update Organization"
     Then I should see "Organization was successfully updated."

  Scenario: update organization see error on invalid slug
     And I am on the organization show page
     And I click the "Settings" link
     When I fill in the organization form with:
        | name | Test Update Organization |
        | slug | #@$ @**))~(_+#!@_^_$HDJ ) |
        | default_account_filter | {"account_filter":"SP18"} |
     And I click on "Update Organization"
     Then I should see "Slug is invalid"
     