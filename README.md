# Optimus Prime Database Assessment

The Optimus Prime Database Assessment tool is used to assess homogenous and hetereogeous migrations of Oracle databases. Assessment results are integrated with Google Big Query to support detailed reporting and analysis. The tool can be used for one or many Oracle databases, and includes the following components:

1. A SQL script (.sql) to collect data from Oracle Database(s)
2. A python script (.py) to import data into Google Big Query

NOTE: The script to collect data only runs SELECT statements against Oracle dictionary and requires read permissions. No application data is accessed, nor is any data changed or deleted.

## How to use this tool

Part 1 - Collecting data from an Oracle database (source)

1. Create an Oracle database user -or- choose an existing user account .
	* If you decide to use an existing database user with all the privileges already assigned please go to Step 3.
2. Run the script called `minimum_select_grants_for_targets.sql` to grant privileges to the user created in Step 1.
	* When prompted, provide the name of the database user created at Step 1.
3. Execute the SQL script called `oracle_db_assessment.sql` for Oracle Database Version 12c and on OR `oracle_db_assessment__11g.sql` for Oracle Database Version 11g.
	* This execution can use any Oracle native tool that supports SQL Script. In some cases some other third party tools as well.
	* For example you can use Oracle SQL*Plus which is the recommended approach.
	* NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB neither in each Oracle RAC instance.
4. Once the script is executed you should see many opdb*log output files generated. It is recommended to zip/tar these files.
	*  All the generated files follow this standard opdb__<queryname>__<dbversion>_<scriptversion>_<hostname>_<dbname>_<instancename>_<datetime>.log.
	*  Use meaningful names when zip/tar the files. 
5. Repeat step 3 for all Oracle databases that you want to assess.

Part 2 - Importing the data collected into Google Big Query for analysis

1. Make sure all the files collected are unzipped and place in a directory of your choice. For example: `/mydir/mydbassessments`.
2. Execute the command below to import your database assessment: 
	*  `python optimusprime.py -dataset newdatasetORexistingdataset -collectionid 071621111714 -fileslocation /mydir/mydbassessments -projectname eri-dbs-migration-test`
	*  `-datatase`: is the name of the dataset in Google Big Query. It is created if it does not exists. If it does already nothing to do then.
	*  `-collectionid`: is the file identification which last numbers in the filename which represents <datetime> (mmddrrhh24miss).
		*  In this example of a filename `opdb__usedspacedetails__121_0.1.0_mydbhost.mycompany.com.ORCLDB.orcl1.071621111714.log` the file identification is `071621111714`.
	*  `-fileslocation`: The location in which the opdb*log were saved.
	*  `-projectname`: The GCP project in which the data will be loaded.
	*  `-deletedataset`: This an optinal. In case you want to delete the whole existing dataset before importing the data. 
		*  WARNING: It will DELETE permanently ALL tables previously in the dataset. No further confirmation will be required. Use it with caution.

Part 3 - Analyzing imported data

1. Open the dataset used in the step 2 of Part 2 in Google Big Query
	*  Query the tables and views for further analysis

## Contributing to the project

Contributions and pull requests are welcome.  See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license.  This is not an officially supported Google project
