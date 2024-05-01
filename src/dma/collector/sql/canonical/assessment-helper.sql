-- name: get-pg-version^
SELECT metric_value FROM collection_postgres_calculated_metrics WHERE metric_name='VERSION';

-- name: insert-readiness-check!
INSERT INTO alloydb_readiness_check_summary (severity, info) VALUES (:severity, :info);