The scripts in this directory can be used to run the DMA collector on a large number of databases.


Execute this process on a jump server or workstation that has access to the databases from which you want to collect data.  
The machine will need the Oracle client installed and network access to the Oracle listener port on each database server.

Configuration:
Edit the file dma_db_list.csv add one line for each database from which to collect.  For multitenant environments, list
only the container databases here.  The data for the pluggable databases will be collected with the container.
You will need the SYS password (or another user that has SYSDBA privileges), 
the username and password to be used by the collector (the dma_make_user.sh script will create this
user if it does not exist), and the database connection definition.  
There is a template in the file.


Prechecks:
There are several scripts provided to verify the environment is ready to run the DMA collector.
Most of these scripts use the dma_db_list.csv file. so ensure it is populated before starting.
The order in which to run these scripts is:

1 : Verify operating system and SYSDBA connectivity.
 dma_precheck_os.sh      -- Verify the operating system has all of the commands and utilties required.
 dma_precheck_sysdba.sh  -- Verify the sysdba user and password are correct by connecting to each database.

2 : Grant privileges to the collector
 dma_make_user.sh        -- Grant required privileges to the specified user for DMA collection.  Will create the user if necessary.

3 : Verify the DMA user connectivity and statistics availability:
 dma_precheck_user.sh    -- Verify the DMA user can connect to each database.
 dma_precheck_stats.sh   -- Verify that the requested statistics source (AWR, STATSPACK or NONE) are available.


Collection execution:
Executing the dma_batch_run.sh script to run the DMA collector on all databases in the dma_db_list.csv file.
By default, up to 5 collections will run in parallel as backgound processes.  This number can be modified
by setting parameter maxParallel as below.  Note that this affects the number of collections running at once,
not the degree of parallelism of the queries.

  ./dma_batch_run.sh --maxParallel 2

Do not set this value too high, as the collection files can take up a lot of space during collection.  Also, if a database server
has several databases on it, you may not want to run all the collections on all the databases simultaneously.

Be sure to remove the csv file containing the passwords once DMA collection is complete.



