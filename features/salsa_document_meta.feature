Feature: salsa_document_meta
as a admin or client
I want the data-meta in the document payload to be tracked in the database.

    Background:
        Given there is a organization with a sub organization
        And that I am logged in as a admin

    @javascript
    Scenario: track document meta for a root organization
        Given the "organization" has:
            | track_meta_info_from_document | true |
            | export_type | Program Outcomes |
        # Given there is a document
        And the "organization" has a "salsa_meta_document"
        And I am on the document edit page
        Then I should see "test_meta"
        When I click the "tb_save" link
        Then I should see "saved at:"
        When I click the "tb_share" link
        # Then inspect "organization"
        Then I should see "HTML link"
        # Then inspect "document"
        And I am on the document edit page
        Then a "DocumentMeta" should be present
        And an "DocumentMeta" should be present with:
            | key | salsa |
            | value | Choose |

    Scenario: track document meta for a sub organization