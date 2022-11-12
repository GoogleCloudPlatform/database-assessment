# Gather workload metadata

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.tar.bz2).

Launch the collection script

- Execute this from a system that can access your database via sqlplus
- Execute from a user with DBA privileges or optionally use the provided creation script
- Pass connect string as input to this script (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.tar.bz2  -O - | tar -xvf
./collect-data.sh {user}/{password}@//{db host/scan address}/{service name}
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics.