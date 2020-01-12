Feature: new_course_select
As a designer i want to have a dialog for creating a new salsa when i come through from my lms

  # ./cucumber.sh features/new_course_select.feature

  Background: 
    Given there is a organization
    And that I am logged in as a admin

  Scenario: i click use as template 
    Given the "organization" has a "document"
    Given i am on the course select page
    # to be continued
  
  
  Scenario: i click create new salsa 