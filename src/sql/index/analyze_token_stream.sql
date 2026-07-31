SELECT tokenized.raw_term,
       UNNEST(
           list_filter(
               [{{term_expression}}],
               lambda term: term IS NOT NULL AND term <> ''
           )
       ) AS term
       {{projected_columns}}
FROM tokenized
WHERE tokenized.raw_term IS NOT NULL
  AND tokenized.raw_term <> ''
{{stopwords_filter}}
