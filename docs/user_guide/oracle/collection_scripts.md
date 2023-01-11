# Gather workload metadata

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip).

Launch the collection script

- Execute this from a system that can access your database via sqlplus
- Execute from a user with DBA privileges or optionally use the provided creation script
- Pass connect string as input to this script (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.
-       If you are licensed for the Oracle Tuning and Diasnostics packs, pass the parameter UseDiagnostics to use the AWR data.
-       If you are NOT licensed for the  Oracle Tuning and Diasnostics packs, pass the parameter NoDiagnositcs to exclude the AWR data.



```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/oracle-database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip  
unzip db-migration-assessment-collection-scripts-oracle.zip

# To use the licensed Oracle Tuning and Diasnostics pack data:
./collect-data.sh {user}/{password}@//{db host/scan address}/{service name} UseDiagnostics
# OR
# To avoid using the licensed Oracle Tuning and Diasnostics pack data:
./collect-data.sh {user}/{password}@//{db host/scan address}/{service name} NoDiagnostics
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics.
