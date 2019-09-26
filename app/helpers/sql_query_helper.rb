
module SqlQueryHelper

    def self.collect_query_settings params, query_options
        params = params.symbolize_keys
        query_options = query_options.symbolize_keys
        query_strings = {}
        query_parameters = {}
        params.each {|k,v| query_parameters[k] = v if query_options.has_key?(k) }
        query_options.each { |k,v| query_strings[k] = v unless v.nil? || !query_parameters.has_key?(k) }
        { params: query_parameters, strings: query_strings }
    end

    def self.get_document_meta org_ids, account_filter, params = {}
        query_options = { 
            :start => "AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)",
            :account_filter=>"AND n.value LIKE :account_filter AND a.key = 'account_id'", 
            :limit=>"offset :offset limit :limit", 
            :offset=>nil,
            :org_ids=>nil,
            :org_ids_string=>nil
        }

        params[:org_ids_string] = org_ids.join(', ')
        params[:org_ids] = org_ids
        params[:account_filter] = "%#{account_filter}%" unless ReportHelper.account_filter_blank?(account_filter)
        params[:offset] = (params[:page] || 1).to_i if params[:page]
        params[:limit] = (params[:per] || 1).to_i if params[:page]

        query_settings = collect_query_settings params, query_options
        
        if query_settings[:params][:start].nil? || (query_settings[:params][:start] = query_settings[:params][:start].gsub(/[^\d-]/, '')) == ''
            query_settings[:strings][:start] = ''
        end

        query_strings = query_settings[:strings]

        DocumentMeta.find_by_sql([
            document_meta_query_sql(query_strings[:account_filter], query_strings[:limit], query_strings[:start]),
            query_settings[:params]
        ])
    end

    def self.get_local_report_data org_ids, account_filter = nil, params = {}
        query_options = { 
            :account_filter=>"AND n.value LIKE :account_filter AND a.key = 'account_id'", 
            :start=>"AND (start.value IS NULL OR CAST(start.value AS DATE) >= :start)", 
            :limit=>"offset :offset limit :limit", 
            :period_id=>"AND ( docs.period_id = :period_id )", 
            :period_slug=>"AND ( pd.slug = :period_slug )", 
            :org_ids=>"AND docs.organization_id IN ( :org_ids )",
            :offset=>nil
        }
        params[:org_ids] = org_ids
        params[:offset] = (params[:page] || 1).to_i if params[:page]
        params[:limit] = (params[:per] || 1).to_i if params[:page]

        query_settings = collect_query_settings params, query_options

        Document.find_by_sql([document_report_data_sql(query_settings[:strings]), query_settings[:params]])
    end

    def self.get_org_chart_data org_ids, params = {}
        query_options = { 
            :limit=>"offset :offset limit :limit",
            :period_slug=>"AND ( pd.slug = :period_slug )", 
            :org_ids=>'WHERE orgs.id IN (:org_ids)'
        }
        params[:org_ids] = org_ids

        query_settings = collect_query_settings params, query_options

        Organization.find_by_sql([org_chart_data_sql(query_settings[:strings]),query_settings[:params]])
    end

    private

    def self.org_chart_data_sql sql_strings
        <<-SQL.gsub(/^ {4}/, '')
            SELECT 
            orgs.id,
            orgs.parent_id,
            orgs.name,
            COUNT(docs.*) total_docs,
            COUNT(docs.lms_published_at) lms_published,
            (COUNT(docs.*) - COUNT(docs.lms_published_at)) lms_unpublished,
            COUNT(docs.published_at) published,
            (COUNT(docs.*) - COUNT(docs.published_at)) unpublished,
            COUNT(docs.lms_course_id) has_lms_course,
            (COUNT(docs.*) - COUNT(docs.lms_course_id)) has_no_lms_course,
            (SELECT COUNT(*) FROM documents WHERE updated_at = created_at AND organization_id = orgs.id) abandoned,
            (SELECT COUNT(*) FROM documents WHERE updated_at <> created_at AND organization_id = orgs.id) maintained
            FROM documents docs
            LEFT JOIN organizations orgs
                ON orgs.id = docs.organization_id
            LEFT JOIN periods as pd
                ON docs.period_id = pd.id
            #{sql_strings[:org_ids]}
            #{sql_strings[:period_slug]}
            GROUP BY orgs.id, orgs.name
            #{sql_strings[:limit]}
        SQL
    end

    def self.document_report_data_sql sql_strings
        <<-SQL.gsub(/^ {4}/, '')
            SELECT DISTINCT
            docs.lms_course_id as course_id,
            orgs.lms_account_id as account_id, 
            -- root_org.name as account,
            orgs.parent_id as parent_id,
            docs.id as document_id,
            docs.id as id,
            docs.name as name,
            -- cc.value as course_code,
            -- et.value as enrollment_term_id,
            -- sis.value as sis_course_id,
            pd.start_date as start_at,
            pd.duration as duration,
            pd.slug as period_slug,
            -- pd.end_date asend_at,
            p_org.name as parent_account_name,
            ws.name as workflow_state, 
            -- ts.value as total_students,
            docs.edit_id as edit_id,
            docs.view_id as view_id,
            docs.lms_published_at as published_at,
            orgs.id as organization_id,
            orgs.name as organization_name,
            pd.id as period_id

            FROM documents as docs

            LEFT JOIN documents as c
            ON c.id = docs.id

            LEFT JOIN organizations as orgs
            ON docs.organization_id = orgs.id
            AND docs.updated_at != docs.created_at

            LEFT JOIN organizations as p_org
            ON orgs.parent_id = p_org.id

            -- LEFT JOIN organization as root_org
            -- AND root_org.parent_id = nil
            -- AND root_org.depth = 0

            LEFT JOIN workflow_steps as ws
            ON docs.workflow_step_id = ws.id

            LEFT JOIN periods as pd
            ON docs.period_id = pd.id

            WHERE docs.created_at != docs.updated_at         
            #{sql_strings[:period_slug]}
            #{sql_strings[:org_ids]}

            ORDER BY docs.lms_published_at, orgs.id

            #{sql_strings[:limit]}
        SQL
    end

    def self.document_meta_query_sql account_filter_sql, limit_sql, start_filter
        <<-SQL.gsub(/^ {4}/, '')
            SELECT DISTINCT a.lms_course_id as course_id,
            a.value as account_id,
            acn.value as account,
            p.value as parent_id,
            d.id as document_id,
            n.value as name,
            cc.value as course_code,
            et.value as enrollment_term_id,
            sis.value as sis_course_id,
            start.value as start_at,
            p.value as parent_id,
            pn.value as parent_account_name,
            end_date.value as end_at,
            ws.value as workflow_state,
            ts.value as total_students,
            d.edit_id as edit_id,
            d.view_id as view_id,
            d.lms_published_at as published_at

            -- prefilter the account id and course id meta information so joins will be faster (maybe...?)
            FROM document_meta as a

            -- join the name meta information
            LEFT JOIN
            document_meta as n ON (
                a.lms_course_id = n.lms_course_id
                AND a.root_organization_id = n.root_organization_id
                AND n.key = 'name'
            )

            -- join the account name
            LEFT JOIN
            organization_meta as acn ON (
                a.value = acn.lms_organization_id
                AND a.root_organization_id = acn.root_id
                AND acn.key = 'name'
            )

            -- join the account parent id
            LEFT JOIN
            organization_meta as p ON (
                acn.lms_organization_id = p.lms_organization_id
                AND acn.root_id = p.root_id
                AND p.key = 'parent_account_id'
            )

            -- join the account parent id
            LEFT JOIN
            organization_meta as pn ON (
                p.value = pn.lms_organization_id
                AND acn.root_id = pn.root_id
                AND pn.key = 'name'
            )

            -- join the course code meta infromation
            LEFT JOIN
            document_meta as cc ON (
                a.lms_course_id = cc.lms_course_id
                AND a.root_organization_id = cc.root_organization_id
                AND cc.key = 'course_code'
            )

            -- join the enrollment term meta information
            LEFT JOIN
            document_meta as et ON (
                a.lms_course_id = et.lms_course_id
                AND a.root_organization_id = et.root_organization_id
                AND et.key = 'enrollment_term_id'
            )

            -- join the sis course id meta information
            LEFT JOIN
            document_meta as sis ON (
                a.lms_course_id = sis.lms_course_id
                AND a.root_organization_id = sis.root_organization_id
                AND sis.key = 'sis_course_id'
            )

            -- join the start date meta information
            LEFT JOIN
            document_meta as start ON (
                a.lms_course_id = start.lms_course_id
                AND a.root_organization_id = start.root_organization_id
                AND start.key = 'start_at'

                #{start_filter}
            )

            -- join the end_date date meta information
            LEFT JOIN
            document_meta as end_date ON (
                a.lms_course_id = end_date.lms_course_id
                AND a.root_organization_id = end_date.root_organization_id
                AND end_date.key = 'end_at'
            )

            -- join the workflow state meta information
            LEFT JOIN
            document_meta as ws ON (
                a.lms_course_id = ws.lms_course_id
                AND a.root_organization_id = ws.root_organization_id
                AND ws.key = 'workflow_state'
            )

            -- join the total_students meta information
            LEFT JOIN
            document_meta as ts ON (
                a.lms_course_id = ts.lms_course_id
                AND a.root_organization_id = ts.root_organization_id
                AND ts.key = 'total_students'
                AND ts.value != '0'
            )

            -- join the SALSA document
            LEFT JOIN
            documents as d ON (
                a.lms_course_id = d.lms_course_id
                AND d.organization_id IN ( :org_ids )
            )

            WHERE
            a.root_organization_id IN (:org_ids)
            #{account_filter_sql}

            ORDER BY pn.value, acn.value, n.value, a.lms_course_id

            #{limit_sql}
        SQL
    end

end





