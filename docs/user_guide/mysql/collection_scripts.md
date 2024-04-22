# Gather workload metadata

The workload collection supports MySQL 5.6 and newer. Older versions of MySQL are not currently supported.  MariaDB is also not currently supported with this version of the script.

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
mysql
sed
tar
tr
which
zip or gzip
```

## Execute collection script

Download the latest collection scripts [here](https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-mysql.zip).

```shell
mkdir ./dbma_collector && cd dbma_collector
wget https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-mysql.zip
unzip db-migration-assessment-collection-scripts-mysql.zip
```

- Execute this from a system that can access your database via mysql command line client.

Execute the collection script with connection parameters:
```
    ./collect-data.sh --collectionUserName root --collectionUserPass secret --hostName myhost.example.com --port 25432 --databaseService sys --vmUserName myuser --extraSSHArg "-p" --extraSSHA
rg "12248"
```
The example above will connect to a database named 'sys' on host myhost.example.com on port 25432 as user "root" with password "secret".  It will also ssh as the current user to myhost.example.com, port 12248 to collect information on about the machine running the database.
  - Parameters
```
 Connection definition must one of:
      {
        --connectionStr       Connection string formatted as {user}/{password}@//{db host}:{listener port}/{service name}
       or
        --hostName            Database server host name
        --port                Database listener port
        --databaseService     Database service name
        --collectionUserName  Database user name
        --collectionUserPass  Database password
      }

  Additional Parameters:
        --manualUniqueId      (Optional) A short string to be attached to this collection.  Use only when directed.

  VM collection definition (optional):
        --vmUserName          Username for the ssh session to --hostName for collecting machine information.
        --extraSSHArg         Extra args to be passed as is to ssh. Can be specified multiple times or as a single quoted string..

```


Examples:

```shell
To collect data for a single database:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name}
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}

 To collect data for all databases in the instance:
  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}
 or
  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port}
```

## Upload Collections

Upon completion, the tool will automatically create an archive of the extracted metrics that can be uploaded into the assessment tool.
