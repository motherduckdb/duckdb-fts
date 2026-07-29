normalized_phrase_fields AS (
    SELECT phrase_field_tf.docid,
           phrase_field_tf.fieldid,
           phrase_field_tf.phrase_idf,
           field_config.field_weight,
           phrase_field_tf.tf / (
               (1.0 - field_config.field_b)
               + field_config.field_b * (
                   list_extract(docs.field_lens, phrase_field_tf.fieldid + 1)
                   / field_config.avg_field_len
               )
           ) AS normalized_tf
    FROM phrase_field_tf
    JOIN {{fts_schema}}.docs AS docs
      ON docs.docid = phrase_field_tf.docid
    JOIN field_config
      ON field_config.fieldid = phrase_field_tf.fieldid
),
phrase_bm25f_frequencies AS (
    SELECT docid,
           any_value(phrase_idf) AS phrase_idf,
           sum(field_weight * normalized_tf) AS pseudo_tf
    FROM normalized_phrase_fields
    GROUP BY docid
),
phrase_bm25f_scores AS (
    SELECT docid,
           phrase_idf * (
               (pseudo_tf * (k + 1))
               / (pseudo_tf + k)
           ) AS score
    FROM phrase_bm25f_frequencies
),
phrase_field_scores AS (
    SELECT docid,
           fieldid,
           field_weight * phrase_idf * (
               (normalized_tf * (k + 1))
               / (normalized_tf + k)
           ) AS field_score
    FROM normalized_phrase_fields
),
phrase_best_field_scores AS (
    SELECT phrase_field_scores.docid,
           max(field_score)
               + params.tie_breaker * (sum(field_score) - max(field_score)) AS score
    FROM phrase_field_scores
    CROSS JOIN params
    GROUP BY phrase_field_scores.docid,
             params.tie_breaker
),
phrase_scores AS (
    SELECT phrase_bm25f_scores.*
    FROM phrase_bm25f_scores
    CROSS JOIN params
    WHERE params.scoring_model = 'bm25f'
    UNION ALL
    SELECT phrase_best_field_scores.*
    FROM phrase_best_field_scores
    CROSS JOIN params
    WHERE params.scoring_model = 'best_fields'
)
