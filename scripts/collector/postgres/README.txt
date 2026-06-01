README
======
Instructions on how to prepare and run Google Database Migration Assessment Data Extractor to extract the data required
for analysis by Database Migration Assessment.

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.
    These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

    b) Database Privileges
    ----------------------
    Running the metadata collector does NOT require database superuser privileges. It is highly 
    recommended to follow the Principle of Least Privilege (PoLP) by creating a dedicated, 
    limited read-only collector role.
    
    Below is the standard DDL SQL template to provision the non-superuser collector role:

        -- 1. Create the dedicated login role
        CREATE ROLE dma_collector WITH LOGIN PASSWORD 'your_secure_password';

        -- 2. Grant connection rights to the target database
        GRANT CONNECT ON DATABASE your_database TO dma_collector;

        -- 3. Grant usage permissions on public/user-defined schemas
        GRANT USAGE ON SCHEMA public TO dma_collector;

        -- 4. Grant SELECT privileges on all pg_catalog and information_schema tables
        GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO dma_collector;
        GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO dma_collector;

        -- 5. Grant pg_read_all_stats default role (PostgreSQL 10+)
        -- This enables high-fidelity reading of active queries, locks, and relation sizes
        GRANT pg_read_all_stats TO dma_collector;


    c) System Requirements
    ----------------------
    The collection script depends on the following to be available on the machine from which it is run:
    bash shell
    cat
    cut
    dirname
    grep
    locale
    mkdir
    sed
    tar
    tr
    which
    zip or gzip


2. Preparation
--------------

    a) Unzip the install archive.

    b) Ensure psql is in the path.

3. Execution
------------

    Execute the collection script with connection parameters:
    ./collect-data.sh --collectionUserName postgres --collectionUserPass secret --hostName myhost.example.com --port 25432 --vmUserName myuser --extraSSHArg -p --extraSSHArg 12248

  Connection definition must one of:
      {
        --connectionStr       Connection string formatted as {user}/{password}@//{db host}:{listener port}/{service name}
       or
        --hostName            Database server host name
        --port                Database listener port
        --databaseService     Database service name (Optional. Defaults to 'postgres'.)
        --collectionUserName  Database user name.
        --collectionUserPass  Database password
      }

  Additional Parameters:
        --allDbs              Collect data for all databases (Y/N).  Optional. Defaults to 'Y'.  Set to N to collect for only the database service given.
        --manualUniqueId      (Optional) A short string to be attached to this collection.  Use only when directed.

  VM collection definition (optional):
        --vmUserName          Username for the ssh session to --hostName for collecting machine information.
                              Must be supplied to collect hardware configuration of the database server if
                              the collection script is not run directly on the database server.
        --extraSSHArg         Extra args to be passed as is to ssh. Can be specified multiple times or as a single quoted string..

 Example:

 To collect data for a single database:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --allDbs N
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --allDbs N

 To collect data for all databases in the instance:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name}
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}



4. Results
----------

    An archive of the extracted results will be created in the directory collector/output.
    The full path and file name will be displayed on completion.


5. License
------------
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


6. Performance Considerations
----------------------------

    The metadata collector executes non-blocking, read-only queries against the database catalogs 
    and statistics views. In typical environments, CPU and I/O overhead is negligible (under 1%).
    
    However, in enterprise high-scale environments containing massive catalog footprints 
    (e.g., >50,000 physical/partitioned tables, complex schema maps, or high-density indexes):
    * Disk Sizing functions (such as pg_relation_size, pg_total_relation_size, and pg_indexes_size) 
      may trigger temporary disk I/O spikes during execution.
    * It is recommended to execute the collection script during off-peak hours or scheduled 
      maintenance windows to minimize any production footprint.
    * Ensure the target server is configured with sufficient connection limits to accommodate the 
      collector session.
