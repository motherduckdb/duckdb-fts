LOAD fts;
SET threads = 2;

CREATE TABLE documents(id VARCHAR NOT NULL, title VARCHAR, body VARCHAR);
INSERT INTO documents
SELECT 'doc' || lpad(i::VARCHAR, 12, '0') AS id,
       'record category' || (i % 100)::VARCHAR || ' region' || (i % 20)::VARCHAR AS title,
       'workspace item search benchmark ' ||
           CASE i % 20
               WHEN 0 THEN 'northstar prefixalpha northstar prefixalpha running'
               WHEN 1 THEN 'northstar prefixbeta runner'
               WHEN 2 THEN 'southstar infixalpha runnable'
               WHEN 3 THEN 'eaststar prefixgamma running'
               WHEN 4 THEN 'weststar infixbeta runner'
               ELSE 'baseline catalog archive'
           END || ' ' || substr(md5(i::VARCHAR), 1, 16) AS body
FROM range(getenv('FTS_BENCHMARK_ROWS')::BIGINT) AS source(i);

CHECKPOINT;

CREATE TEMP TABLE footprint_before AS
SELECT total_blocks * block_size AS database_bytes
FROM pragma_database_size()
WHERE database_name = current_database();

PRAGMA create_fts_index(
    'documents',
    'id',
    'title',
    'body',
    stemmer='porter',
    stopwords='none',
    layered_search=true,
    incremental=true
);

CHECKPOINT;

SELECT count(*) AS source_rows,
       (SELECT count(*) FROM fts_main_documents.terms) AS positional_posting_rows,
       any_value(footprint_before.database_bytes) AS base_database_bytes,
       any_value(database_size.total_blocks * database_size.block_size) AS indexed_database_bytes,
       any_value(
           database_size.total_blocks * database_size.block_size
           - footprint_before.database_bytes
       ) AS index_bytes
FROM documents
CROSS JOIN footprint_before
CROSS JOIN pragma_database_size() AS database_size
WHERE database_size.database_name = current_database();
