WITH tokenized AS (
    {{union_fields_query}}
),
stemmed_stopped AS (
    {{analyzed_tokens}}
)
