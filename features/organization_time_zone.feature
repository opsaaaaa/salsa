# is test is vary simular to keiths tests and can probably be added to one of his

Feature: set organization time zone
as a organization admin
In order to have the timestaps match my organizations time zone
I want to be able to set my organizations time zone


  Scenario: update organization time zone

    Given there is a organization
    And that I am logged in as a admin
    And I am on the organization edit page
    When I set the time zone a given time zome
    And I click update "Update Organization"
    Then i should see "Organization Updated Successfuly."
    And the organzation time zone should be updated to the given time zone 