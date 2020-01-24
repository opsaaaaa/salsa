Feature: document template
I want templated documents to be created correctly.

  # ./cucumber.sh features/document_name.feature

  Background: 
    Given there is a organization with a default period
    And that I am logged in as a admin
  
  Scenario: template a new document as with a name
    Given the "organization" has a "document"
    When i visit that documents template page with:
        | name | Crazy Template Document Name |
    Then an "document" should be present with:
        | name | Crazy Template Document Name |

  Scenario: templates should use the default period.

        