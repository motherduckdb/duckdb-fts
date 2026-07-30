SELECT token.w,
       fts_ii.rowid AS docid,
       {{field_id}} AS fieldid,
       token.position::UINTEGER AS position
FROM {{input_table}} AS fts_ii
CROSS JOIN LATERAL UNNEST(
    list_filter(
        {{fts_schema}}.tokenize(fts_ii.{{input_value}}),
        lambda value: value IS NOT NULL AND value <> ''
    )
) WITH ORDINALITY AS token(w, position)
