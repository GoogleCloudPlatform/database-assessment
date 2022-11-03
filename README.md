# Optimus Prime Database Assessment

The Optimus Prime Database Assessment tool is used to assess homogenous migrations of Oracle databases. Assessment results are integrated with Google BigQuery to support detailed reporting and analysis. The tool can be used for one or many Oracle databases, and includes the following components:

1. A SQL script (.sql) to collect data from Oracle Database(s)
2. A python script (.py) to import data into Google BigQuery
3. A Data Studio template that can be used to generate assessment report

> NOTE: The script to collect data only runs SELECT statements against Oracle dictionary and requires read permissions. No application data is accessed, nor is any data changed or deleted.

## How to use this tool

### Step 1 - Database setup (Create readonly user with required privileges)

#### Database user creation.

Create an Oracle database user -or- choose an existing user account .

- If you decide to use an existing database user with all the privileges already assigned please go to Step 1.4.

if creating a user within a CDB find out the common_user_prefix and then create the user like so, as higher privileged user (like sys):

```sql
select * from v$system_parameter where name='common_user_prefix';
--C##
create user C##optimusprime identified by "mysecretPa33w0rd";
```

if creating a application user within a PDB create a regular user

```sql
create user optimusprime identified by "mysecretPa33w0rd";
```

#### Clone _optimus prime_ into your work directory in a client machine that has connectivity to your databases

```shell
cd <work-directory>
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment
```

#### Verify 3 Grants scripts under (@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/)

- grants_wrapper.sql
- minimum_select_grants_for_targets_12c_AND_ABOVE.sql
- minimum_select_grants_for_targets_ONLY_FOR_11g.sql

  1.3.1a Run the script grants_wrapper.sql which will call Grants script based on your database version (`minimum_select_grants_for_targets_12c_AND_ABOVE.sql` for Oracle Database Version 12c and above OR `minimum_select_grants_for_targets_ONLY_FOR_11g.sql` for Oracle Database Version 11g) to grant privileges to the user created in Step 1.

```sql
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/grants_wrapper.sql
-- Please enter the DB Local Username(Or CDB Username) to receive all required grants: [C##]optimusprime
```

> NOTE: grants_wrapper.sql has provided variable db_awr_license which is set default to Y to access AWR tables. AWR is a licensed feature of Oracle. If you don't have license to run AWR you can disable flag and it will execute script minimum_select_grants_for_targets_ONLY_FOR_11g.sql.

OR

1.3.1b You can run appropriate script based your database version (`minimum_select_grants_for_targets_12c_AND_ABOVE.sql` for Oracle Database Version 12c and above OR `minimum_select_grants_for_targets_ONLY_FOR_11g.sql` for Oracle Database Version 11g) to grant privileges to the user created in Step 1.

For Database version 11g and below

```sql
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/minimum_select_grants_for_targets_ONLY_FOR_11g.sql
-- Please enter the DB Local Username(Or CDB Username) to receive all required grants: [C##]optimusprime
```

For Database version 12c and above

```sql
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/minimum_select_grants_for_targets_12c_AND_ABOVE.sql
```

#### Execute /home/oracle/oracle-database-assessment/db_assessment/dbSQLCollector/collectData-Step1.sh to start collecting the data.

- Execute this from a system that can access your database via sqlplus
- Pass connect string as input to this script (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.

```shell
cd /<work-directory>/oracle-database-assessment

./scripts/collectData-Step1.sh optimusprime/mysecretPa33w0rd@//<serverhost>/<servicename>
```

#### Once the script is executed you should see many opdb\*.log output files generated. It is recommended to zip/tar these files.

- All the generated files follow this standard `opdb__<queryname>__<dbversion>_<scriptversion>_<hostname>_<dbname>_<instancename>_<datetime>.log`
- Use meaningful names when zip/tar the files.

Example output:

```shell
oracle@oracle12c oracle-database-assessment-output]$ ls
manual__alertlog__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log            opdb__dbsummary__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistcmdtypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log       opdb__freespaces__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistosstat__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log         opdb__indexestypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistsysmetrichist__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log  opdb__partsubparttypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__compressbytable__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log       opdb__patchlevel__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__compressbytype__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log        opdb__pdbsinfo__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__cpucoresusage__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log         opdb__pdbsopenmode__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__datatypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log             opdb__sourcecode__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbfeatures__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log            opdb__spacebyownersegtype__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbhwmarkstatistics__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log    opdb__spacebytablespace__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbinstances__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log           opdb__systemstats__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dblinks__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log               opdb__tablesnopk__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbobjects__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log             opdb__usedspacedetails__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbparameters__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log          opdb__usrsegatt__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbservicesinfo__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log

```

The table below demonstrates, at a high level, the information that is being collected along with a brief explanation on how it will be used.

| Output Filename(s)                | Data Collected                                                                | Justification/Context                                                                                                                              | Dictionary Views                                                                                                                                                                                                               |
| :-------------------------------- | :---------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| opdb\__awrsnapdetails_\*log       | Begin time, End time and the count of snapshots available.                    | Provide information about both the retention and the amount of data available                                                                      | dba_hist_snapshot                                                                                                                                                                                                              |
| opdb\__opkeylog_\*log             | Host, database name, instance name, collection time                           | Create a unique identifier when importing multiple collection in the same BigQuery data set                                                        | NA                                                                                                                                                                                                                             |
| opdb*dbsummary*\*log              | Dbname, DbVersion, Dbsizes, RAC Instances, etc                                | It will provide us a high level view of the database and its main attributes                                                                       | v$database, cdb_users,dba_users, v$instance, v$database,gv$instance, nls_database_parameters,v$version,v$log_history,v$log,v$sgastat,v$pgastat, cdb_data_files,dba_data_files, cdb_segments,dba_segments,logstdby$skip_support |
| opdb*pdbsinfo*\*log               | DBID, PDBIDs, PDBNames and Status                                             | Overview of the PDBs/applications being used                                                                                                       | cdb_pdbs (Applicable only to version 12c and superior in multitenant architecture)                                                                                                                                             |
| opdb*pdbsopenmode*\*log           | PDBSize                                                                       | Storage used by PDBs/application                                                                                                                   | v$pdbs (Applicable only to version 12c and superior in multitenant architecture)                                                                                                                                               |
| opdb*dbinstances*\*log            | InstanceName, Hostname, etc                                                   | If Oracle RAC being used and how many instances                                                                                                    | gv$instance                                                                                                                                                                                                                    |
| opdb*usedspacedetails*\*log       | SegmentType by Owner                                                          | Some SegmentType are not supported in other databases (in case of modernization), can offer upgrades with improvements (Example LOB to SecureLOB)  | cdb_segments, logstdby$skip_support                                                                                                                                                                                            |
| opdb*compressbytable*\*log        | Compressed Tables By Owner                                                    | Have a more accurate idea of the DbSize and possible attention points for migration                                                                | cdb_tables,dba_tables,cdb_segments,dba_segments, cdb_tab_partitions,dba_tab_partitions, cdb_tab_subpartitions,dba_tab_subpartitions, logstdby$skip_support                                                                     |
| opdb*compressbytype*\*log         | Compressed Tables by CompressionType                                          | Have a more accurate idea of the DbSize                                                                                                            | cdb_tables,dba_tables, cdb_segments,dba_segments,cdb_tab_partitions,dba_tab_partitions, cdb_tab_subpartitions,dba_tab_subpartitions, logstdby$skip_support                                                                     |
| opdb*spacebyownersegtype*\*log    | Used Storage by Owner by SegmentType                                          | How much (storage) of SegmentTypes are in the database. It helps in case of modernization and handling workarounds for it                          | cdb_segments,dba_segments, logstdby$skip_support                                                                                                                                                                               |
| opdb*spacebytablespace*\*log      | Tablespaces Parameters and Fragmentation                                      | It gives an idea about storage consumption for tablespaces                                                                                         | cdb_segments, dba_segments,cdb_tablespaces,dba_tablespaces logstdby$skip_support                                                                                                                                               |
| opdb*freespaces*\*log             | Storage by Tablespace by PDB                                                  | Database Storage used Versus Storage allocated                                                                                                     | cdb_data_files,dba_data_files cdb_free_space,dba_free_space cdb_tablespaces,dba_tablespaces v$temp_space_header                                                                                                                |
| opdb*dblinks*\*log                | DBLinkName, HostName by PDB                                                   | It tells about the database dependencies                                                                                                           | cdb_db_links,dba_db_links,logstdby$skip_support                                                                                                                                                                                |
| opdb*dbparameters*\*log           | Database Parameters                                                           | Can be used to spot database features, dependencies, replications, memory, instance caging, etc                                                    | gv$parameter                                                                                                                                                                                                                   |
| opdb*dbfeatures*\*log             | Database Proprietary Features Being Used                                      | Can be used to identify first movers, database lock-in and assist on modernization plan                                                            | cdb_feature_usage_statistics,dba_feature_usage_statistics                                                                                                                                                                      |
| opdb*dbhwmarkstatistics*\*log     | Database Limits Reached                                                       | To be used as reference to identify potential target databases                                                                                     | dba_high_water_mark_statistics                                                                                                                                                                                                 |
| opdb*cpucoresusage*               | History of Cores Allocated                                                    | Assist in sizing exercise                                                                                                                          | dba_cpu_usage_statistics                                                                                                                                                                                                       |
| opdb*dbobjects*\*log              | ObjectTypes by Owner by PDB                                                   | Some ObjectType are not supported in other databases                                                                                               | cdb_objects,dba_objects,logstdby$skip_support                                                                                                                                                                                  |
| opdb*sourcecode*\*log             | Number of Lines of Code by Type by Owner by PDB                               | It helps to understand effort to modernize the database and application                                                                            | cdb_source,dba_source,logstdby$skip_support                                                                                                                                                                                    |
| opdb*partsubparttypes*\*log       | PartitionTableType by Owner by PDB                                            | Some partition types are not supported in other databases                                                                                          | cdb_part_tables,dba_part_tables, logstdby$skip_support                                                                                                                                                                         |
| psodb*indexestypes*\*log          | IndexType by Owner by PDB                                                     | Some index types are not supported in other databases                                                                                              | cdb_indexes,dba_indexes, logstdby$skip_support                                                                                                                                                                                 |
| psodb*datatypes*\*log             | Data Types by Owner by PDB                                                    | Some DataType are not supported in other databases                                                                                                 | cdb_tab_columns, dba_tab_columns,logstdby$skip_support                                                                                                                                                                         |
| opdb*tablesnopk*\*log             | Summary by PDB by Owner of Table Constraints                                  | Evaluate if this is candidate to logical migration online                                                                                          | cdb_tables,dba_tables, cdb_constraints,dba_constraints                                                                                                                                                                         |
| opdb\_\_systemstats\*log          | Values for CPU speed, IO transfer speed, single and multiblock read speed     | Analyze current key performance metrics of the current environment. This details influence on database behaviour like SQL execution plan.          | sys.aux_stats$                                                                                                                                                                                                                 |
| opdb*patchlevel*\*log             | Patchset, PSU, RUs, RURs Applied in the DB                                    | Identify the current patch level for the database                                                                                                  | dba_registry_sqlpatch,registry$history                                                                                                                                                                                         |
| opdb*alertlog*\*log               | Database alert log                                                            | Assist on analyzing if the current system is healthy enough to be migrated                                                                         | v$diag_alert_ext                                                                                                                                                                                                               |
| opdb*awrhistsysmetrichist*\*log   | Database Stats (CPU, IO requests, throughput, transactions) by Hour by DB/PDB | Sizing exercise, overprovision analysis                                                                                                            | dba_hist_snapshot, dba_hist_sysmetric_history                                                                                                                                                                                  |
| opdb\_\_awrhistsysmetricsumm\*log | Database Stats (CPU, IO requests, throughput, transactions) by Hour by DB/PDB | Sizing exercise, overprovision analysis                                                                                                            | dba_hist_snapshot,dba_hist_sysmetric_summary                                                                                                                                                                                   |
| opdb*awrhistosstat*\*log          | OS statistics collected by Database engine by Hour by DB/PDB                  | Sizing exercise, overprovision analysis                                                                                                            | dba_hist_osstat, dba_hist_snapshot                                                                                                                                                                                             |
| opdb*awrhistcmdtypes*\*log        | SQL Stats (CPU, IO) by command type                                           | Assist on identifying the workload type and best target database for modernization                                                                 | dba_hist_sqlstat, dba_hist_sqltext, dba_hist_snapshot                                                                                                                                                                          |
| opdb\_\_dbahistsystimemodel\*log  | Database stats (DBtime, CPU, background CPU, parse time) by hour by DB/PDB    | Sizing exercise, overprovision analysis                                                                                                            | dba_hist_sys_time_model,dba_hist_snapshot                                                                                                                                                                                      |
| opdb\_\_dbahistsysstat\*log       | Database stats (DBtime, redo, IO)                                             | Sizing exercise, overprovision analysis                                                                                                            | dba_hist_sysstat, dba_hist_snapshot                                                                                                                                                                                            |
| opdb\_\_dbservicesinfo\*log       | Database services - Used for connection handling and Application failover     | Support how applications connects to database and handle failover scenarios                                                                        | dba_services,cdb_services                                                                                                                                                                                                      |
| opdb\_\_usrsegatt\*log            | Map user schemas with segments/objects created in SYS/SYSTEM tablespaces      | Support database migration strategies                                                                                                              | dba_segments,cdb_segments,system.logstdby$skip_support                                                                                                                                                                         |

1.6. Repeat step 1.3 for all Oracle databases that you want to assess.

### Step 2 - Importing the data collected into Google BigQuery for analysis

Much of the data import and report generation has been automated. Follow section 2.1 to use the automated process. Section 2.2 provides instructions for the manual process if that is your preference. Both processes assume you have rights to create datasets in a Big Query project and access to Data Studio.

Make note of the project name and the data set name and location. The data set will be created if it does not exist.

2.1 Automated load process

These instructions are written for running in a Cloud Shell environment. Ensure that your environment is configured to access the Google Cloud project you want to use:

```shell
gcloud config set project [PROJECT_ID]
```

2.1.1 Clone the Optimus Prime codebase to a working directory.

Create a working directory for the code base, then clone the repository from Github.

Ex:

```shell
mkdir -p ~/code/op
cd ~/code/op
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment
```

2.1.2 Create a data directory and upload files from the client

Create a directory to hold the output files for processing, then upload the files to that location and uncompress.

Ex:

```shell
mkdir ~/data
<upload files to data>
cd data
<uncompress files>
```

2.1.3 Configure automation

The automated load process is configured via setting several environment variables and then executing a set of scripts in the <workingdirectory>/oracle-database-assessment/scripts/ directory.

Set these environment variables prior to starting the data load process:

```shell
# Required
# This is the name of the project into which you want to load data
export PROJECTNAME=yourProjectNameHere

# Required
# This is the name of the data set into which you want to load.
# The dataset will be created if it does not exist.
# If the datset already exists, it will have this data appoended.
# Use only alphanumeric characters, - (dash) or _ (underscore)
# This name must be filesystem and html compatible
export DSNAME=yourDatasetNameHere

# Required
# This is the location in which the dataset should be created.
export DSLOC=yourRegionNameHere

# Required
# This is the full path into which the customer's files have been extracted.
export OPOUTPUTDIR=/full/Path/To/CollectionFiles

# Optional
# This is the name of the report you want to create in DataStudio upon load completion.
# Use only alphanumeric characters or embed HTML encoding.
# Defaults to "OptimusPrime%20Dashboard%20${DSNAME}"
export REPORTNAME=yourReportNameHere

# Optional
# This is the column separator used in the input data files.
# Previous versions of Optimus Prime used ';' (semicolon).
# Defaults to | (pipe)
export COLSEP='|'
```

2.1.4 Execute the load scripts

The load scripts expect to be run from the <workingdirectory>/oracle-database-assessment/scripts directory. Change to this directory and run the following commands in numeric order. Check output of each for errors before continuing to the next.

```shell
./scripts/1_activate_op.sh
./scripts/2_load_op.sh
./scripts/3_run_op_etl.sh
./scripts/4_gen_op_report_url.sh
```

The function of each script is as follows.

- \_configure_op_env.sh - Defines environment variables that are used in the other scripts. This script is executed only by the other scripts in the loading process.
- 1_activate_op.sh - Installs necessary Python support modules and activates the Python virtual environment for Optimus Prime.
- 2_load_op.sh - Loads the client data files into the base Optimus Prime tables in the requested data set.
- 3_run_op_etl.sh - Installs and runs Big Query procedures that create additional views and tables to support the Optimus Prime dashboard.
- 4_gen_op_report_url.sh - Generates the URL to view the newly loaded data using a report template.

  2.1.5 View the data in Optimus Prime Dashboard report

Click the link displayed by script 4_gen_op_report_url.sh to view the report. Note that this link does not persist the report.
To save the report for future use, click the '"Edit and Share"' button, then '"Acknowledge and Save"', then '"Add to Report"'. It will then show up in Data Studio in '"Reports owned by me"' and can be shared with others.

Skip to step 3 to perform additional analysis for anything not contained in the dashboard report.

2.2 Manual load process

2.2.1. Setup Environment variables (From Google Cloud Shell ONLY).

```shell
gcloud auth list

gcloud config set project <project id>
```

2.2.2 Export Environment variables. (Step 1.2 has working directory created)

```shell
export OP_WORKING_DIR=$(pwd)
export OP_BQ_DATASET=[Dataset Name]
export OP_OUTPUT_DIR=/$OP_WORKING_DIR/oracle-database-assessment-output/<assessment output directory>
mkdir $OP_OUTPUT_DIR/log
export OP_LOG_DIR=$OP_OUTPUT_DIR/log
```

2.2.3 Create working directory (Skip if you have followed step 1.2 on same server)

```shell
mkdir $OP_WORKING_DIR
```

2.2.4 Clone Github repository (Skip if you have followed step 1.2 on same server)

```shell
cd <work-directory>
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment
```

2.2.5 Create assessment output directory

```shell
mkdir -p /<work-directory>/oracle-database-assessment-output
cd /<work-directory>/oracle-database-assessment-output
```

2.2.6 Move zip files to assessment output directory and unzip

```shell
mv <file file> /<work-directory>/oracle-database-assessment-output
unzip <zip files>
```

2.2.7. [Create a service account and download the key](https://cloud.google.com/iam/docs/creating-managing-service-accounts#before-you-begin) .

- Set GOOGLE_APPLICATION_CREDENTIALS to point to the downloaded key. Make sure the service account has BigQuery Admin privilege.
- NOTE: This step can be skipped if using [Cloud Shell](https://ssh.cloud.google.com/cloudshell/)

  2.2.8. Create a python virtual environment to install dependencies and execute the `optimus-prime` script

```shell
 python3 -m venv $OP_WORKING_DIR/.venv
 source $OP_WORKING_DIR/.venv/bin/activate
 cd $OP_WORKING_DIR/oracle-database-assessment/

 pip3 install pip wheel setuptools --upgrade
 pip3 install .

 # If you want to import one single Optimus Prime file collection (From 1 single database), please follow the below step:

 optimus-prime -dataset newdatasetORexistingdataset -collectionid 080421224807 --files-location /<work-directory>/oracle-database-assessment-output --project-name my-awesome-gcp-project -importcomment "this is for prod"

 # If you want to import various Optimus Prime file collections (From various databases) that are stored under the same directory being used for --files-location. Then, you can add to your command two additional flags (--from-dataframe -consolidatedataframes) and pass only "" to -collectionid. See example below:

 optimus-prime -dataset newdatasetORexistingdataset -collectionid "" --files-location /<work-directory>/oracle-database-assessment-output --project-name my-awesome-gcp-project --from-dataframe -consolidatedataframes

#  If you want to import only specific db version or sql version from Optimus Prime file collections hat are stored under the same directory being used for --files-location.

 optimus-prime -dataset newdatasetORexistingdataset -collectionid "" --files-location /<work-directory>/oracle-database-assessment-output --project-name my-awesome-gcp-project --from-dataframe -consolidatedataframes --filter-by-db-version 11.1 --filter-by-sql-version 2.0.3

 # If you want to akip all file validations

 optimus-prime -dataset newdatasetORexistingdataset -collectionid "" --files-location /<work-directory>/oracle-database-assessment-output --project-name my-awesome-gcp-project -skipvalidations
```

- `--dataset`: is the name of the dataset in Google BigQuery. It is created if it does not exists. If it does already nothing to do then.
- `--collection-id`: is the file identification which last numbers in the filename which represents `<datetime> (mmddrrhh24miss)`.
- In this example of a filename `opdb__usedspacedetails__121_0.1.0_mydbhost.mycompany.com.ORCLDB.orcl1.071621111714.log` the file identification is `071621111714`.
- `--files-location`: The location in which the opdb\*log were saved.
- `--project-name`: The GCP project in which the data will be loaded.
- `--delete-dataset`: This an optinal. In case you want to delete the whole existing dataset before importing the data.
  - WARNING: It will DELETE permanently ALL tables previously in the dataset. No further confirmation will be required. Use it with caution.
- `--import-comment`: This an optional. In case you want to store any comment about the load in opkeylog table. Eg: "This is for Production import"
- `--filter-by-sql-version`: This an optional. In case you have files from multiple sql versions in the folder and you want to load only specific sql version files
- `--filter-by-db-version`: This an optional. In case you have files from multiple db versions in the folder and you want to load only specific db version files
- `--skip-validations`: This is optional. Default is False. if we use the flag, file validations will be skipped

- > NOTE: If your file has elapsed time or any other string except data, run the following script to remove it

```shell
for i in `grep "Elapsed:" $OP_OUTPUT_DIR/*.log |  cut -d ":" -f 1`; do sed -i '$ d' $i; done
```

### Step 3 - Analyzing imported data

3.1. Open the dataset used in the step 2 of Part 2 in Google BigQuery

- Query the viewnames starting with vReport\* for further analysis
- Sample queries are listed, they provide
  - Source DB Summary
  - Source Host details
  - Google Bare Metal Sizing
  - Google Bare Metal Pricing
  - Migration Recommendations

## Contributing to the project

Contributions and pull requests are welcome. See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license. This is not an officially supported Google project
