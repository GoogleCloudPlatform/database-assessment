SELECT 'BMS Sizing Per Database (All Instances Included)' bms_sizing_description
       ,
       NULL                                               hostname,
       a.db_name,
       a.dbversion,
       c.max_source_num_cpu_cores,
       a.bms_machine_offer,
       a.bms_machine_offer_cores,
       a.bms_offer_processor,
       a.bms_offer_est_price,
       a.bms_database_memory_gb,
       a.bms_db_tb_disk_for_iops,
       a.bms_est_monthly_storage_bill
FROM   mydataset.vbms_sizing_bmsserverperdb a
       INNER JOIN (SELECT b.db_name,
                          b.dbversion,
                          b.dbid,
                          MAX(b.source_num_cpu_cores)
       max_source_num_cpu_cores,
                          MAX(b.source_db_cpu_utilization_perc)
                         max_source_db_cpu_utilization_perc,
                          MAX(b.source_host_cpu_utilization_perc)
                         max_source_host_cpu_utilization_perc
                   FROM   mydataset.vbms_sizing_detailperdb b
                   GROUP  BY b.db_name,
                             b.dbversion,
                             b.dbid) c
               ON a.db_name = c.db_name
                  AND a.dbversion = c.dbversion
                  AND a.dbid = c.dbid
UNION ALL
SELECT 'BMS Sizing Per Host (All Databases Included)',
       b.hostname,
       NULL db_name,
       NULL dbversion,
       d.max_source_num_cpu_cores,
       b.bms_machine_offer,
       b.bms_machine_offer_cores,
       b.bms_offer_processor,
       b.bms_offer_est_price,
       b.bms_database_memory_gb,
       b.bms_db_tb_disk_for_iops,
       b.bms_est_monthly_storage_bill
FROM   mydataset.vbms_sizing_bmsserverperhost b
       INNER JOIN (SELECT b.hostname,
                          MAX(b.source_num_cpu_cores)
              max_source_num_cpu_cores,
                          MAX(b.source_host_cpu_utilization_perc)
                         max_source_host_cpu_utilization_perc
                   FROM   mydataset.vbms_sizing_detailperhost b
                   GROUP  BY b.hostname) d
               ON b.hostname = d.hostname; 
