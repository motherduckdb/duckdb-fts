SELECT unnest(tokens) AS raw_term,
       fts_ii.docid AS docid,
       (SELECT fieldid
        FROM {{fts_schema}}.fields
        WHERE field = {{input_value_string}}) AS fieldid,
       generate_subscripts(tokens, 1)::UINTEGER AS position
FROM (
    SELECT fts_ii.docid,
           list_filter(
               {{fts_schema}}.tokenize(fts_ii.{{input_value}}),
               lambda token: token IS NOT NULL AND token <> ''
           ) AS tokens
    FROM fts_new_docs AS fts_ii
) AS fts_ii
