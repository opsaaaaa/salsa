Feature: salsa_document_meta
as a admin or client
I want the data-meta in the document payload to be tracked in the database.

    Background:
        Given there is a organization with a sub organization
        And that I am logged in as a admin
        And I am on the organization show page
        # And that I am logged in as a admin

    @javascript
    Scenario: track document meta for a root organization
        # Given the "organization" has:
            # | track_meta_info_from_document | true |
        # And the "organization" has a "document"
        # And I am on the document edit page
        # And I click the "tb_save" link

    Scenario: track document meta for a sub organization