Feature: document_search
as a admin or client
In order to find specific documents 
I want to be able search the documents beloning to the current organization.

    Background:
        Given there is a organization with a sub organization
        And that I am logged in as a admin

    Scenario: I see the search bar
        Given I am on the organization show page
        Then I should see "Search"

    Scenario: I search for an existing document
        Given the "organization" has a "document" with:
            | name | an existing document name |
        And the "document" should be present
        When I search documnets for "an existing document name"
        Then I should see "an existing document name" 

    Scenario: I search for an non-existing document
        When I search documnets for "a non-existing document name"
        Then I should see "No documents found"

    Scenario: setting document_search_includes_sub_organizations is true
        Given the "organization" has:
            | document_search_includes_sub_organizations | true |
        Given the "sub_organization" has a "document" with:
            | name | sub_organization document |
        When I search documnets for "sub_organization document"
        Then I should see "sub_organization document"

    Scenario: setting document_search_includes_sub_organizations is false
        Given the "organization" has:
            | document_search_includes_sub_organizations | false |
        Given the "sub_organization" has a "document" with:
            | name | sub_organization document |
        When I search documnets for "sub_organization document"
        Then I should see "No documents found"