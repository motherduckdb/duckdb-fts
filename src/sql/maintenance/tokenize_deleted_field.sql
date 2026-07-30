SELECT unnest({{fts_schema}}.tokenize(fts_di.{{input_value}})) AS raw_term
FROM fts_old_rows AS fts_di
