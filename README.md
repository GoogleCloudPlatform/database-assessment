# Optimus Prime Database Assessment

This project intends to enable an easier Oracle database assessment for homogenous and hetereogeous migration. It is integrated with Google Big Query database what makes easy to query all data collected. This tool can be used for one or many Oracle databases. It will cover:

1. Script to collect data from Oracle Databases
2. Script to import this data to be analyzed into Google Big Query
3. Script to create some views that add value to the analysis. For instance, Database Migration Effort Estimate, Google Bare Metal Sizing, etc.

NOTE: The script to collect data only runs SELECT statements against Oracle dictionary. No application data is accessed nor is any data changed or deleted.

## How to use this tool

Part 1 - Collecting the data in the Oracle source system

1. Create an Oracle database user with minimum provileges to collect data from Oracle dictionary.
	* If you decide to use an existing database user with all the privileges already please go to step 3.
2. Run the script called `minimum_select_grants_for_targets.sql`
	* When prompted, provide the name of the database user created at Step 1.
3. Execute the SQL script called `oracle_db_assessment.sql`.
	* This execution can use any Oracle native tool that supports SQL Script. In some cases some other third party tools as well.
	* For example you can use Oracle SQL*Plus which is the recommended approach.
	* NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB neither in each Oracle RAC instance.
4. Once the script is executed you should see many psodb*log files generated. It might be a good idea to zip/tar those files.
	* Please use meaningful names when zip/tar the files. For instance, dbassess_<hostname>_<dbname>_<PROD or NON-PROD>.tar.
5. Repeat step 3 for all Oracle databases that you want to assess.

Part 2 - Importing the data collected into Google Big Query for analysis

To Be Developed

## Contributing to the project

Contributions and pull requests are welcome.  See [docs/contributing.md](docs/contributing.md) and [docs/code-of-conduct.md](docs/code-of-conduct.md) for details.

## The fine print

This product is [licensed](LICENSE) under the Apache 2 license.  This is not an officially supported Google project
