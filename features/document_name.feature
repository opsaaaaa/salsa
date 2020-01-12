Feature: document_name
I want my documents to be named automaticly when the name param is passed.

  # ./cucumber.sh features/document_new.feature

  Background: 
    Given there is a organization
    And that I am logged in as a admin

  Scenario: create a new document with a name
    When i visit the document new page with:
        | name | Crazy New Document Name |
    Then an "document" should be present with:
        | name | Crazy New Document Name |
  
  Scenario: template a new document as with a name
    Given the "organization" has a "document"
    When i visit that documents template page with:
        | name | Crazy Template Document Name |
    Then an "document" should be present with:
        | name | Crazy Template Document Name |


        