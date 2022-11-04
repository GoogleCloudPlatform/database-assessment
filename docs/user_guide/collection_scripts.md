# Gather workload metadata

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/collection_scripts.tar.bz2).

Extract these files to a location that has access to the database from SQL\*Plus

```shell
tar xvf collection_scripts.tar.bz2
cd collector

```

Launch the collection script

- Execute this from a system that can access your database via sqlplus
- Pass connect string as input to this script (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.

```shell
./collect-data.sh \
 optimusprime/Pa55w__rd123@//{db host/scan address}/{service name}
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics. It is important that this file be submitted as is and without modifications.

- All files within the archive should follow the following naming convention:
  `opdb__<query_name>__<db_version>_<script_version>_<hostname>_<db_name>_<instance_name>_<datetime>.csv`
- Data is pipe `|` delimited
