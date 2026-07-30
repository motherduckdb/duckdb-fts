WITH {{new_docs_cte}},
tokenized AS (
    {{union_fields_query}}
),
stemmed_stopped AS (
    {{analyzed_tokens}}
)
