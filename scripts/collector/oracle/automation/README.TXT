Many customers have requested a way to automate the configuration and execution of the DMA collector across a large number of databases.  
The files in this directory provide one method to accomplish this in a way that relies only on minimal shell commands and the Oracle client.  
The method presented here is not a best practice or even very secure, but can be used in a pinch if allowed by your organization.

Execute this process on a jump server or workstation that has access to the databases from which you want to collect data.  
The machine will need the Oracle client installed and network access to the Oracle listener port on each database server.

Configuration:
Edit the file dma_db_list.csv add one line for each database from which to collect.  
You will need the SYS password (or another user that has SYSDBA privileges), 
the username and password to be used by the collector (the dma_make_user.sh script will create this
user if it does not exist), and the database connection definition.  
There is a template in the file.


Prechecks:
There are several scripts provided to verify the environment is ready to run the DMA collector.
Most of these scripts use the dma_db_list.csv file. so ensure it is populated before starting.
The order in which to run these scripts is:
 dma_precheck_os.sh      -- Verify the operating system has all of the commands and utilties required.
 dma_precheck_sysdba.sh  -- Verify the sysdba user and password are correct by connecting to each database.


Granting privileges for DMA collection:
Once the dma_db_list.csv file is created, run the dma_make_user.sh script to create the user (if necessary) 
and grant the required privileges to run the collection.


Verify the DMA user connectivity and statistics availability:
 dma_precheck_user.sh    -- Verify the DMA user can connect to each database.
 dma_precheck_stats.sh   -- Verify that the requested statistics source (AWR, STATSPACK or NONE) is available.


Execution:
Executing the dma_batch_run.sh script to run the DMA collector on all databases in the dma_db_list.csv file.
By default, up to 5 collections will run in parallel as backgound processes.  This number can be modified
by setting parameter maxParallel as below:

  ./dma_batch_run.sh --maxParallel 10

Do not set this value too high, as the collection files can take up a lot of space during collection.  Also, if a database server
has several databases on it, you may not want to run all the collections on all the databases simultaneously.





