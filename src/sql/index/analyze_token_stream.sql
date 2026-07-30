SELECT analyzed.*
FROM (
    SELECT tokenized.raw_term,
           {{term_expression}} AS term
           {{projected_columns}}
    FROM tokenized
    WHERE tokenized.raw_term IS NOT NULL
      AND tokenized.raw_term <> ''
    {{stopwords_filter}}
) AS analyzed
WHERE analyzed.term IS NOT NULL
  AND analyzed.term <> ''
