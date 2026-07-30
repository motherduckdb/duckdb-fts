CREATE MACRO {{fts_schema}}.match_bm25(docname, query_string, fields := NULL, k := 1.2, b := 0.75, conjunctive := false, field_weights := NULL, field_b := NULL, scoring_model := 'bm25f', tie_breaker := 0.0) AS (
    WITH params AS (
        SELECT field_weights::MAP(VARCHAR, DOUBLE) AS field_weights,
               field_b::MAP(VARCHAR, DOUBLE) AS field_b,
               lower(scoring_model::VARCHAR) AS scoring_model,
               tie_breaker::DOUBLE AS tie_breaker,
               b::DOUBLE AS default_b
    ),
    {{field_scoring_config_ctes}}
    tokenized AS (
        SELECT unnest({{fts_schema}}.tokenize(query_string)) AS raw_term
    ),
    analyzed_query_tokens AS (
        {{analyzed_tokens}}
    ),
    tokens AS (
        SELECT DISTINCT term AS t
        FROM analyzed_query_tokens
    ),
    qtermids AS (
        SELECT termid
        FROM {{fts_schema}}.dict AS dict,
             tokens
        WHERE dict.term = tokens.t
    ),
    qterms AS (
        SELECT termid,
               docid,
               fieldid
        FROM {{fts_schema}}.terms AS terms
        WHERE fieldid IN (SELECT fieldid FROM field_config)
          AND termid IN (SELECT qtermids.termid FROM qtermids)
    ),
    cdocs AS (
        SELECT docid
        FROM qterms
        GROUP BY docid
        HAVING CASE WHEN conjunctive THEN COUNT(DISTINCT termid) = (SELECT COUNT(*) FROM tokens) ELSE 1 END
    ),
    field_term_tf AS (
        SELECT qterms.termid,
               NULL::BIGINT AS rawtermid,
               qterms.docid,
               qterms.fieldid,
               any_value(
                   log(
                       ((((stats.num_docs - dict.df) + 0.5)
                           / (dict.df + 0.5)) + 1)
                   )
               ) AS idf,
               1.0::DOUBLE AS expansion_weight,
               count(*) AS tf
        FROM qterms
        JOIN cdocs ON cdocs.docid = qterms.docid
        JOIN {{fts_schema}}.dict AS dict ON dict.termid = qterms.termid
        CROSS JOIN {{fts_schema}}.stats AS stats
        GROUP BY qterms.docid,
                 qterms.fieldid,
                 qterms.termid
    ),
    {{field_scoring_score_ctes}}
    SELECT score
    FROM scores,
         {{fts_schema}}.docs AS docs
    WHERE scores.docid = docs.docid
      AND docs.name = docname
    UNION ALL
    SELECT error(message)::DOUBLE
    FROM validation_errors
);
