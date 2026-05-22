# Gather workload metadata

!!! note
    For Postgres homogeneous migrations, please upload the collections files to Google Migration Center


The workload collection supports Postgres 12 and newer. Older versions of Postgres are not currently supported.

## System environment

The collection script is designed to run in a Unix or Unix-like environment. It can be run on Windows within either Windows subsystem for Linux or Cygwin.
It depends on the following to be available on the machine from which it is run:

```shell
bash shell
cat
cut
dirname
grep
locale
mkdir
psql
sed
tar
tr
which
zip or gzip
```

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-postgres.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-postgres.zip
unzip db-migration-assessment-collection-scripts-postgres.zip
```

- Execute this from a system that can access your database via psql

### User Creation

Please refer to the standalone [User Creation](db_user_create.md) guide for options on executing data collections via default superusers or bootstrapping least-privileged collector accounts.

### Permissions

Data collection requires access to basic monitoring stats and system catalogs. Consult the dedicated [Permissions](permissions.md) file for complete reference matrices on minimum required database connection grants and built-in viewing roles.

- NOTE: The collector can be run for a single database or all databases in the instance.

Execute the collection script with connection parameters:

```
    ./collect-data.sh --collectionUserName postgres --collectionUserPass secret --hostName myhost.example.com --port 25432 --vmUserName myuser --extraSSHArg -p --extraSSHArg 12248
```

The example above will connect to a database named 'postgres' (the default) on host myhost.example.com on port 25432 as user "postgres" with password "secret".  It will also ssh as the current user to myhost.example.com, port 12248 to collect information on about the machine running the database.

- Parameters

```
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

```

Examples:

```shell
To collect data for a single database:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --allDbs N
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --allDbs N

 To collect data for all databases in the instance:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name}
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics for upload into the DMA application.  Do not modify the file names or contents.

!!! important
    Do not modify the name or the contents of the zip file without consultation from Google.

## License

Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
