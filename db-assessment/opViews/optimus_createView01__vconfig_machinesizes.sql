SELECT TRIM(a.cores)              cores,
       TRIM(a.ram_gb)             ram_gb,
       TRIM(a.machine_size)       machine_size,
       TRIM(a.machine_size_short) machine_size_short,
       TRIM(a.processor)          processor,
       TRIM(a.est_price)          est_price
FROM   mydataset.optimusconfig_bms_machinesizes a;
