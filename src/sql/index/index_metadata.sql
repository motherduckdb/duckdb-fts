CREATE VIEW {{fts_schema}}.index_metadata AS
WITH canonical_stopwords AS (
    SELECT DISTINCT sw
    FROM {{fts_schema}}.stopwords
),
stopword_config AS (
    SELECT md5(
               coalesce(
                   string_agg(
                       CASE
                           WHEN sw IS NULL THEN 'n;'
                           ELSE 's:' || length(sw)::VARCHAR || ':' || sw || ';'
                       END,
                       '' ORDER BY sw NULLS FIRST
                   ),
                   ''
               )
           ) AS content_hash
    FROM canonical_stopwords
),
analyzer_metadata AS (
    SELECT {{analyzer_config}}
           || 'stopwords:'
           || length(content_hash)::VARCHAR
           || ':'
           || content_hash
           || ';' AS analyzer_config
    FROM stopword_config
)
SELECT {{format_version}}::UINTEGER AS format_version,
       {{incremental}}::BOOLEAN AS incremental,
       {{cluster_terms}}::BOOLEAN AS cluster_terms,
       {{layered_search}}::BOOLEAN AS layered_search,
       {{positions}}::BOOLEAN AS positions,
       (SELECT list(field ORDER BY fieldid) FROM {{fts_schema}}.fields)::VARCHAR[] AS fields,
       {{stemmer}}::VARCHAR AS stemmer,
       {{stopwords}}::VARCHAR AS stopwords,
       {{tokenizer}}::VARCHAR AS tokenizer,
       {{ignore}}::VARCHAR AS ignore,
       {{strip_accents}}::BOOLEAN AS strip_accents,
       {{lower}}::BOOLEAN AS lower,
       analyzer_config,
       md5(analyzer_config)::VARCHAR AS analyzer_fingerprint
FROM analyzer_metadata;
