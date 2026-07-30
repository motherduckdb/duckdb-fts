CREATE MACRO {{fts_schema}}.analyze_text(s) AS TABLE
WITH positioned_tokens AS (
    SELECT token.raw_term,
           token.position::UINTEGER AS position
    FROM UNNEST(
        list_filter(
            {{fts_schema}}.tokenize(s),
            lambda value: value IS NOT NULL AND value <> ''
        )
    ) WITH ORDINALITY AS token(raw_term, position)
),
tokenized AS (
    SELECT raw_term,
           position
    FROM positioned_tokens
),
analyzed_tokens AS (
    {{analyzed_tokens}}
),
token_stream AS (
    SELECT raw_term,
           term,
           position,
           (
               position
               - coalesce(lag(position) OVER (ORDER BY position), 0)
           )::UINTEGER AS position_increment
    FROM analyzed_tokens
)
SELECT raw_term,
       term,
       position,
       position_increment,
       1::UINTEGER AS position_length,
       NULL::UINTEGER AS start_offset,
       NULL::UINTEGER AS end_offset,
       'word'::VARCHAR AS token_type
FROM token_stream;
