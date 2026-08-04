CREATE TABLE {{fts_schema}}.term_stats AS
SELECT termid,
       term,
       df,
       length(term)::BIGINT AS term_len,
       greatest(length(term) - 2, 0)::BIGINT AS gram_count
FROM {{fts_schema}}.dict
WHERE term <> '';

CREATE TABLE {{fts_schema}}.term_stats_by_len AS
SELECT termid,
       term,
       df,
       term_len,
       gram_count
FROM {{fts_schema}}.term_stats
ORDER BY term_len,
         df,
         termid;

CREATE TABLE {{fts_schema}}.term_grams AS
SELECT 'g' || lower(hex(substr(term, i, 3))) AS gram,
       termid
FROM {{fts_schema}}.term_stats,
     range(1, gram_count + 1) AS r(i)
WHERE gram_count > 0
  AND NOT regexp_full_match(term, '[0-9]+')
ORDER BY gram,
         termid;

CREATE TABLE {{fts_schema}}.term_prefixes AS
SELECT prefix_len,
       substr(raw_dict.raw_term, 1, prefix_len) AS prefix,
       raw_dict.rawtermid
FROM {{fts_schema}}.raw_dict AS raw_dict,
     (VALUES (2::UTINYINT), (3::UTINYINT)) AS prefix_lengths(prefix_len)
WHERE length(raw_dict.raw_term) >= prefix_len
ORDER BY prefix_len,
         prefix,
         raw_dict.rawtermid;

CREATE TABLE {{fts_schema}}.raw_term_grams AS
SELECT unnest(list_distinct([
           'g' || lower(hex(substr(raw_dict.raw_term, i, 3)))
           FOR i IN range(1, length(raw_dict.raw_term) - 1)
       ])) AS gram,
       raw_dict.rawtermid
FROM {{fts_schema}}.raw_dict AS raw_dict
JOIN {{fts_schema}}.dict AS dict USING (termid)
WHERE length(raw_dict.raw_term) >= 3
  AND (
      raw_dict.raw_term <> dict.term
      OR regexp_full_match(raw_dict.raw_term, '[0-9]+')
  )
ORDER BY gram,
         raw_dict.rawtermid;

CREATE INDEX {{term_stats_term_index}} ON {{fts_schema}}.term_stats(term);
CREATE INDEX {{term_grams_gram_index}} ON {{fts_schema}}.term_grams(gram);
CREATE INDEX {{term_prefixes_prefix_index}} ON {{fts_schema}}.term_prefixes(prefix_len, prefix);
CREATE INDEX {{raw_term_grams_gram_index}} ON {{fts_schema}}.raw_term_grams(gram);

ANALYZE {{fts_schema}}.term_stats;
ANALYZE {{fts_schema}}.term_stats_by_len;
ANALYZE {{fts_schema}}.term_grams;
ANALYZE {{fts_schema}}.raw_dict;
ANALYZE {{fts_schema}}.term_prefixes;
ANALYZE {{fts_schema}}.raw_term_grams;
