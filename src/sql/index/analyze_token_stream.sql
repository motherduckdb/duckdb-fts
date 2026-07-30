SELECT tokenized.raw_term,
       {{term_expression}} AS term
       {{passthrough}}
FROM tokenized
WHERE tokenized.raw_term IS NOT NULL
  AND tokenized.raw_term <> ''
{{stopwords_filter}}
