WITH bms_machine_sizing_by_pdb AS
(
           SELECT     a.ckey,
                      a.db_name,
                      a.dbversion,
                      a.dbid,
                      a.instance_number,
                      a.con_id,
                      CAST(b.cores AS INT64) - a.bms_host_machine_cores                                                                                            bms_host_machine_cores_left,
                      b.machine_size                                                                                                                               bms_machine_offer,
                      b.cores                                                                                                                                      bms_machine_offer_cores,
                      b.processor                                                                                                                                  bms_offer_processor,
                      b.est_price                                                                                                                                  bms_offer_est_price,
                      ROUND((a.bms_host_machine_cores) / CAST(b.cores AS INT64) * 100,0)                                                                           bms_est_cpu_usage_peak,
                      MIN(CAST(b.cores AS INT64)       - a.bms_host_machine_cores) over(PARTITION BY a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number) AS min_bms_machine
           FROM       mydataset.vbms_sizing_summperpdb a
           cross join mydataset.vconfig_machinesizes b
           WHERE      ((
                                            cast(b.cores AS int64) - a.bms_host_machine_cores) / cast(b.cores AS int64) * 100) > 30
           ORDER BY   (cast(b.cores AS int64) - a.bms_host_machine_cores) )
SELECT a.ckey,
       a.db_name,
       a.dbversion,
       a.dbid,
       a.instance_number,
       a.con_id,
       a.bms_machine_offer,
       a.bms_machine_offer_cores,
       a.bms_offer_processor,
       a.bms_offer_est_price,
       a.bms_est_cpu_usage_peak
FROM   bms_machine_sizing_by_pdb a
WHERE  a.bms_host_machine_cores_left = min_bms_machine;
