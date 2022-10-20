--name: transform-07!
CREATE or replace TABLE V_DS_dbfeatures AS
SELECT pkey,
    con_id,
    name,
    current_usage,
    CAST(detected_usages as numeric) as detected_usage,
    total_samples,
    first_usage,
    last_usage,
    aux_count
FROM dbfeatures;