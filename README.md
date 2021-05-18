# Optimus Prime Database Assessment

The Optimus Prime Database Assessment tool is used to assess homogenous and hetereogeous migrations of Oracle databases. Assessment results are integrated with Google Big Query to support detailed reporting and analysis. The tool can be used for one or many Oracle databases, and includes the following components:

1. A script (.sql) to collect data from Oracle Database(s)
2. A script (.sql) to import data into Google Big Query
3. A script (.sql) to create views to support data analysis including Database Migration Effort Estimate and Google Bare Metal Sizing.

NOTE: The script to collect data only runs SELECT statements against Oracle dictionary and requires read permissions. No application data is accessed, nor is any data changed or deleted.

## How to use this tool

Part 1 - Collecting the data from an Oracle database (source)

1. Create an Oracle database user -or- choose an existing user account .
	* If you decide to use an existing database user with all the privileges already assigned please go to Step 3.
2. Run the script called `minimum_select_grants_for_targets.sql` to grant privileges to the user created in Step 1.
	* When prompted, provide the name of the database user created at Step 1.
3. Execute the SQL script called `oracle_db_assessment.sql`.
	* This execution can use any Oracle native tool that supports SQL Script. In some cases some other third party tools as well.
	* For example you can use Oracle SQL*Plus which is the recommended approach.
	* NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB neither in each Oracle RAC instance.
4. Once the script is executed you should see many psodb*log output files generated. It is recommended to zip/tar these files.
	*  Use meaningful names when zip/tar the files. For instance, dbassess_<hostname>_<dbname>_<PROD or NON-PROD>.tar.
5. Repeat step 3 for all Oracle databases that you want to assess.

Part 2 - Importing the data collected into Google Big Query for analysis

To Be Developed

## Contributing to the project

Contributions and pull requests are welcome.  See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license.  This is not an officially supported Google project
