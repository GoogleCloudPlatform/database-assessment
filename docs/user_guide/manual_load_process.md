# Manual load process

## Setup Environment variables (From Google Cloud Shell ONLY)

```shell
gcloud auth list

gcloud config set project <project id>
```

## Export Environment variables. (Step 1.2 has working directory created)

```shell
export OP_WORKING_DIR=$(pwd)
export OP_BQ_DATASET=[Dataset Name]
export OP_OUTPUT_DIR=/$OP_WORKING_DIR/oracle-database-assessment-output/<assessment output directory>
mkdir $OP_OUTPUT_DIR/log
export OP_LOG_DIR=$OP_OUTPUT_DIR/log
```

## Create working directory (Skip if you have followed step 1.2 on same server)

```shell
mkdir $OP_WORKING_DIR
```

## Clone Github repository (Skip if you have followed step 1.2 on same server)

```shell
cd <work-directory>
git clone https://github.com/GoogleCloudPlatform/oracle-database-assessment
```

## Create assessment output directory

```shell
mkdir -p /<work-directory>/oracle-database-assessment-output
cd /<work-directory>/oracle-database-assessment-output
```

## Move zip files to assessment output directory and unzip

```shell
mv <file file> /<work-directory>/oracle-database-assessment-output
unzip <zip files>
```

## [Create a service account and download the key](https://cloud.google.com/iam/docs/creating-managing-service-accounts#before-you-begin)

- Set GOOGLE_APPLICATION_CREDENTIALS to point to the downloaded key. Make sure the service account has BigQuery Admin privilege.
- NOTE: This step can be skipped if using [Cloud Shell](https://ssh.cloud.google.com/cloudshell/)

## Create a python virtual environment to install dependencies and execute the `optimusprime.py` script

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
- `--delete-dataset`: This an optional. In case you want to delete the whole existing dataset before importing the data.
  - WARNING: It will DELETE permanently ALL tables previously in the dataset. No further confirmation will be required. Use it with caution.
- `--import-comment`: This an optional. In case you want to store any comment about the load in opkeylog table. Eg: "This is for Production import"
- `--filter-by-sql-version`: This an optional. In case you have files from multiple sql versions in the folder and you want to load only specific sql version files
- `--filter-by-db-version`: This an optional. In case you have files from multiple db versions in the folder and you want to load only specific db version files
- `--skip-validations`: This is optional. Default is False. if we use the flag, file validations will be skipped

- > NOTE: If your file has elapsed time or any other string except data, run the following script to remove it

```shell
for i in `grep "Elapsed:" $OP_OUTPUT_DIR/*.log |  cut -d ":" -f 1`; do sed -i '$ d' $i; done
```
