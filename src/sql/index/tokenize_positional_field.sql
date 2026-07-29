SELECT unnest(tokens) AS w,
       fts_ii.rowid AS docid,
       {{field_id}} AS fieldid,
       generate_subscripts(tokens, 1)::UINTEGER AS position
FROM (
    SELECT fts_ii.rowid,
           list_filter(
               {{fts_schema}}.tokenize(fts_ii.{{input_value}}),
               lambda token: token IS NOT NULL AND token <> ''
           ) AS tokens
    FROM {{input_table}} AS fts_ii
) AS fts_ii
