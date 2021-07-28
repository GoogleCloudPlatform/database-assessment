WITH bms_machine_sizing_by_hostname AS
(
           SELECT     a.hostname,
                      CAST(b.cores AS INT64) - a.bms_host_machine_cores                                             bms_host_machine_cores_left,
                      b.machine_size                                                                                bms_machine_offer,
                      b.cores                                                                                       bms_machine_offer_cores,
                      b.processor                                                                                   bms_offer_processor,
                      b.est_price                                                                                   bms_offer_est_price,
                      ROUND((a.bms_host_machine_cores) / CAST(b.cores AS INT64) * 100,0)                            bms_est_cpu_usage_peak,
                      MIN(CAST(b.cores AS INT64)       - a.bms_host_machine_cores) over(PARTITION BY a.hostname) AS min_bms_machine,
                      a.bms_database_memory_gb,
                      a.bms_db_tb_disk_for_iops,
                      a.bms_est_monthly_storage_bill
           FROM       ${dataset}.vbms_sizing_summperhost a
           cross join ${dataset}.vconfig_machinesizes b
           WHERE      ((
                                            cast(b.cores AS int64) - a.bms_host_machine_cores) / cast(b.cores AS int64) * 100) > 30
           ORDER BY   (cast(b.cores AS int64) - a.bms_host_machine_cores) )
SELECT a.hostname,
       a.bms_machine_offer,
       a.bms_machine_offer_cores,
       a.bms_offer_processor,
       a.bms_offer_est_price,
       a.bms_est_cpu_usage_peak,
       a.bms_database_memory_gb,
       a.bms_db_tb_disk_for_iops,
       a.bms_est_monthly_storage_bill
FROM   bms_machine_sizing_by_hostname a
WHERE  a.bms_host_machine_cores_left = min_bms_machine;
