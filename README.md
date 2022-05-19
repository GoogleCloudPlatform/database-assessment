# Optimus Prime Database Assessment

The Optimus Prime Database Assessment tool is used to assess homogenous migrations of Oracle databases. Assessment results are integrated with Google Big Query to support detailed reporting and analysis. The tool can be used for one or many Oracle databases, and includes the following components:

1. A SQL script (.sql) to collect data from Oracle Database(s)
2. A python script (.py) to import data into Google Big Query
3. A Data Studio template that can be used to generate assessment report

NOTE: The script to collect data only runs SELECT statements against Oracle dictionary and requires read permissions. No application data is accessed, nor is any data changed or deleted.

# How to use this tool

## Step 1 - Database setup (Create readonly user with required priviledges)

1.1. Database user creation.

Create an Oracle database user -or- choose an existing user account .
	* If you decide to use an existing database user with all the privileges already assigned please go to Step 1.3.


```
if creating a user within a CDB find out the common_user_prefix and then create the user like so, as higher priveleged user (like sys):
select * from v$system_parameter where name='common_user_prefix';
--C##
create user C##optimusprime identified by "mysecretPa33w0rd";

 if creating a application user within a PDB create a regular user
create user optimusprime identified by "mysecretPa33w0rd";

```

1.2. Clone *optimus prime* into your work directory in a client machine that has connectivity to your databases

```
cd <work-directory>
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment

```

1.3. Verfiy 3 Grants scripts under (@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/) 
   * grants_wrapper.sql
   * minimum_select_grants_for_targets_12c_AND_ABOVE.sql
   * minimum_select_grants_for_targets_ONLY_FOR_11g.sql
   
1.3.1a Run the script grants_wrapper.sql which will call Grants script based on your database version (`minimum_select_grants_for_targets_12c_AND_ABOVE.sql` for Oracle Database Version 12c and above OR `minimum_select_grants_for_targets_ONLY_FOR_11g.sql` for Oracle Database Version 11g) to grant privileges to the user created in Step 1. 

	
```
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/grants_wrapper.sql
Please enter the DB Local Username(Or CDB Username) to receive all required grants: [C##]optimusprime

```


NOTE: grants_wrapper.sql has provided variable db_awr_license which is set default to Y to access AWR tables. AWR is a licensed feature of Oracle. If you don't have license to run AWR you can disable flag and it will execute script minimum_select_grants_for_targets_ONLY_FOR_11g.sql.

OR

1.3.1b You can run appropriate script based your database version (`minimum_select_grants_for_targets_12c_AND_ABOVE.sql` for Oracle Database Version 12c and above OR `minimum_select_grants_for_targets_ONLY_FOR_11g.sql` for Oracle Database Version 11g) to grant privileges to the user created in Step 1. 

For Database version 11g and below

```
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/minimum_select_grants_for_targets_ONLY_FOR_11g.sql
Please enter the DB Local Username(Or CDB Username) to receive all required grants: [C##]optimusprime

```

For Database version 12c and above

```
@/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/minimum_select_grants_for_targets_12c_AND_ABOVE.sql

```

1.4. Execute /home/oracle/oracle-database-assessment/db_assessment/dbSQLCollector/collectData-Step1.sh to start collecting the data.
	* Execute this from a system that can access your database via sqlplus
	* Pass connect string as input to this script (see below for example)
	* NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.

```

mkdir -p /<work-directory>/oracle-database-assessment-output

cd /<work-directory>/oracle-database-assessment-output

/<work-directory>/oracle-database-assessment/db_assessment/dbSQLCollector/collectData-Step1.sh optimusprime/mysecretPa33w0rd@//<serverhost>/<servicename>

```

1.5. Once the script is executed you should see many opdb\*.log output files generated. It is recommended to zip/tar these files.
	* All the generated files follow this standard  `opdb__<queryname>__<dbversion>_<scriptversion>_<hostname>_<dbname>_<instancename>_<datetime>.log`
	* Use meaningful names when zip/tar the files.

```
Example output:

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


1.6. Repeat step 1.3 for all Oracle databases that you want to assess.

## Step 2 - Importing the data collected into Google Big Query for analysis

2.1. Setup Environment variables (From Google Cloud Shell ONLY).

```
gcloud auth list

gcloud config set project <project id>

```

2.2 Export Environment variables. (Step 1.2 has working directory created)

```

export OP_WORKDING_DIR=<<path for working directory>
export OP_BQ_DATASET=<<BigQuery Dataset Name>>
export OP_OUTPUT_DIR=/$OP_WORKDING_DIR/oracle-database-assessment-output/<<assessment output directory>
mkdir $OP_OUTPUT_DIR/log
export OP_LOG_DIR=$OP_OUTPUT_DIR/log

```

2.3 Create working directory (Skip if you have followed step 1.2 on same server)

```
mkdir $OP_WORKDING_DIR
```

2.4 Clone Github repository (Skip if you have followed step 1.2 on same server)

```
cd <work-directory>
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment
```

2.5 Create assessment output directory

```
mkdir -p /<work-directory>/oracle-database-assessment-output
cd /<work-directory>/oracle-database-assessment-output
```

2.6 Move zip files to assessment output directory and unzip

```
mv <<file file>> /<work-directory>/oracle-database-assessment-output
unzip <<zip files>>
```

2.7. [Create a service account and download the key](https://cloud.google.com/iam/docs/creating-managing-service-accounts#before-you-begin ) . 
	* Set GOOGLE_APPLICATION_CREDENTIALS to point to the downloaded key. Make sure the service account has BigQuery Admin privelege. 
	* NOTE: This step can be skipped if using [Cloud Shell](https://ssh.cloud.google.com/cloudshell/)

2.8. Create a python virtual environment to install dependencies and execute the `optimusprime.py` script

```
	python3 -m venv $OP_WORKDING_DIR/op-venv
	source $OP_WORKDING_DIR/op-venv/bin/activate
	cd $OP_WORKDING_DIR/oracle-database-assessment/
	
	pip3 install pip --upgrade
	pip3 install .
	
	cd $OP_WORKDING_DIR/oracle-database-assessment/db_assessment/

	If you want to import one single Optimus Prime file collection (From 1 single database), please follow the below step:

	python optimusprime.py -dataset newdatasetORexistingdataset -collectionid 080421224807 -fileslocation /<work-directory>/oracle-database-assessment-output -projectname my-awesome-gcp-project -importcomment "this is for prod"

	If you want to import various Optimus Prime file collections (From various databases) that are stored under the same directory being used for -fileslocation. Then, you can add to your command two additional flags (-fromdataframe -consolidatedataframes) and pass only "" to -collectionid. See example below:

	python optimusprime.py -dataset newdatasetORexistingdataset -collectionid "" -fileslocation /<work-directory>/oracle-database-assessment-output -projectname my-awesome-gcp-project -fromdataframe -consolidatedataframes
	
	If you want to import only specific db version or sql version from Optimus Prime file collections hat are stored under the same directory being used for -fileslocation.  

    python optimusprime.py -dataset newdatasetORexistingdataset -collectionid "" -fileslocation /<work-directory>/oracle-database-assessment-output -projectname my-awesome-gcp-project -fromdataframe -consolidatedataframes -filterbydbversion 11.1 -filterbysqlversion 2.0.3
	
	If you want to akip all file validations 

    python optimusprime.py -dataset newdatasetORexistingdataset -collectionid "" -fileslocation /<work-directory>/oracle-database-assessment-output -projectname my-awesome-gcp-project -skipvalidations
	
	
```

*  `-dataset`: is the name of the dataset in Google Big Query. It is created if it does not exists. If it does already nothing to do then.
*  `-collectionid`: is the file identification which last numbers in the filename which represents `<datetime> (mmddrrhh24miss)`.
*  In this example of a filename `opdb__usedspacedetails__121_0.1.0_mydbhost.mycompany.com.ORCLDB.orcl1.071621111714.log` the file identification is `071621111714`.
*  `-fileslocation`: The location in which the opdb*log were saved.
*  `-projectname`: The GCP project in which the data will be loaded.
*  `-deletedataset`: This an optinal. In case you want to delete the whole existing dataset before importing the data. 
	*  WARNING: It will DELETE permanently ALL tables previously in the dataset. No further confirmation will be required. Use it with caution.
* `-importcomment`: This an optional. In case you want to store any comment about the load in opkeylog table. Eg: "This is for Production import"
* `-filterbysqlversion`: This an optional. In case you have files from multiple sql versions in the folder and you want to load only specific sql version files
* `-filterbydbversion`: This an optional. In case you have files from multiple db versions in the folder and you want to load only specific db version files
* `-skipvalidations`: This is optional. Default is False. if we use the flag, file validations will be skipped 

* NOTE: If your file has elapsed time or any other string except data, fun following script to remove it

```
for i in `grep "Elapsed:" $OP_OUTPUT_DIR/*.log |  cut -d ":" -f 1`; do sed -i '$ d' $i; done
```

## Step 3 - Analyzing imported data

3.1. Open the dataset used in the step 2 of Part 2 in Google Big Query
	*  Query the viewnames starting with vReport* for further analysis
	*  Sample queries are listed, they provide
		*  Source DB Summary
		*  Source Host details
		*  Google Bare Metal Sizing
		*  Google Bare Metal Pricing
		*  Migration Recommendations
	*  Sample [Assessment Report](report/Optimus_Prime_-_dashboard.pdf), was created in DataStudio. A similar report can be generated using the queries for your datasets as part of the assessment readout.

## Contributing to the project

Contributions and pull requests are welcome.  See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license.  This is not an officially supported Google project
