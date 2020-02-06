Feature: document
As a teacher
I want to be able to create a syllabus
in order to define what my class will be doing

  # ./cucumber.sh features/document.feature

  Background:
    Given there is a organization

  Scenario: create document
    Given I am on the "/" page
    When I click the "new_salsa" link
    Then I should see "My SALSA"
    And I should be on the edit document page

  Scenario: view document
    Given there is a document
    And I am on the document view page
    Then I should see "My SALSA"

  @javascript
  Scenario: edit document
    Given there is a document
    And that I am logged in as a admin on the organization
    And I am on the document edit page
    And I click the "tb_save" link
    Then I should see "saved at:"
    And the document should be associated with my user

  Scenario: template document
    Given there is a document
    And I am on the document edit page
    When I click the "view_url" link
    Then I should see "My SALSA"
    And I should see a new document edit url