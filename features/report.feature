Feature: Download report
as a auditor
In order to view my docs
I want to be able to download a report


  Scenario: download report
    # TODO fix this to work with S3
    Given there is a organization
    And that I am logged in as a admin
    And there are documents with document_metas that match the filter
    And the reports are generated
    And I am on the admin reports page for organization

    When I click the "Download Report" link
    Then I should receive the report file
    And the Report zip file should have documents in it
