select trim(a.cores) cores, trim(a.ram_gb) ram_gb, trim(a.machine_size) machine_size, 
      trim(a.machine_size_short) machine_size_short, trim(a.processor) processor, trim(a.est_price) est_price 
from `MYDATASET.optimusconfig_bms_machinesizes` a;
