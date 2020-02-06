Feature: document_new
I want to assert that new documents are create with the correctly.

  # ./cucumber.sh features/document_name.feature

  Background: 
    Given there is a organization
    And that I am logged in as a admin

  Scenario: create a new document with a name
    When i visit the document new page with:
        | name | Crazy New Document Name |
    Then an "document" should be present with:
        | name | Crazy New Document Name |
  


        