Feature: document template
I want templated documents to be created correctly.

  # ./cucumber.sh features/document_name.feature

  Background: 
    Given there is a organization with a sub organization
    And that I am logged in as a admin
    And the "organization" has a "document"
  
  Scenario: template a new document as with a name
    When i visit that documents template page with:
        | name | Crazy Template Document Name |
    Then an "document" should be present with:
        | name | Crazy Template Document Name |

  Scenario: templates should use the current period.
    Given there is a default period
    And there is a old period
    And the "document" belongs to the "old_period"
    When i visit that documents template page with:
        | name | A document with the Default Period |
    Then an "document" should be present with:
        | name | A document with the Default Period |
    Then the new document should belong to the default period
        