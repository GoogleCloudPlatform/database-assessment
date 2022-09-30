# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


import datetime
import glob
import logging
import os
import re

import pandas as pd
from beautifultable import BeautifulTable
from google.api_core.exceptions import Conflict
from google.cloud import bigquery

from db_assessment import rules_engine, set_client_info
from db_assessment.version import __version__

ct = datetime.datetime.now()


logger = logging.getLogger()
logger.setLevel(level=logging.INFO)


def consolidate_collection(args, transformersTablesSchema):

    # This function intents to consolidate the collected files into a single large file to facilitate importing the data to Big Query

    # Creating Hash Table with all expected tableName schemas to be imported
    tableSchemas = {}
    tableSchemas = get_bq_job_config(transformersTablesSchema, "REGULAR")

    # Counting all processed files
    fileCounter = 0

    # For all expected tables we will look for related OS files. So, we will process all files related to a given expected tableName, then move to the next
    for tableName in tableSchemas:

        fileCounter = fileCounter + 1

        # Using the expected tableName to look for files in the OS in the directory passed in --files-location (default dbResults)
        csvFilesLocationPattern = str(getattr(args, "files_location")) + "/opdb*" + str(tableName) + "*.csv"

        # Generating a list with all found OS filenames
        fileList = list_files(csvFilesLocationPattern)

        # To control how many files are being processed and identify the first processed file since it needs to bring the headers
        fileTableCounter = 0

        # Processing one file at a time for the expected tableName
        for fileName in fileList:

            # File Counter
            fileTableCounter = fileTableCounter + 1

            # Final table name from the CSV file names
            tableName = get_obj_name_from_files(fileName, "__", 1)

            # Filename to be used to name consolidated file
            targetFileNameConsolidated = (
                str(getattr(args, "files_location")) + "/opalldb__" + str(tableName) + "__consolidate.csv"
            )

            # Checks if file already exists in the first matching file found because the other files need to append to existent one.
            if fileTableCounter == 1:

                # If already exists delete the file
                if os.path.exists(targetFileNameConsolidated):

                    print(
                        "The file {} already exists. It is going to be overwritten.".format(targetFileNameConsolidated)
                    )
                    os.remove(targetFileNameConsolidated)

            # This is the file that will be used to be consolidated
            fileConsolidated = open(targetFileNameConsolidated, "a")

            # This file was found in the OS. The content of this file will be merged/consolidated into fileConsolidated
            fileToBeConsolidated = open(fileName, "r")

            # Breaking it down into lines because first two lines must be skipped for all of the files (expect first file merged)
            # Since those files are expected to be small (< 10k lines) no performance issue is expected
            linesToBeConsolidated = []
            linesToBeConsolidated = fileToBeConsolidated.readlines()

            # To control how many lines are being processed and identify the first processed lines since it needs to skip it eventually
            lineCounter = 0
            for line in linesToBeConsolidated:

                # Line counters to be used to skip unecessary lines
                lineCounter = lineCounter + 1

                # Not processing first lines due to expected CSV headers. Except for the first file.
                if lineCounter <= 2 and fileTableCounter > 1:

                    continue

                # Writing up the line from linesToBeConsolidated into fileConsolidated
                fileConsolidated.write(line)

            # Closing file handle
            fileToBeConsolidated.close()

            # Closing file handle
            fileConsolidated.close()

    print(
        "\nThe total files consolidated are {}. \nAll files are located in {}".format(
            str(fileCounter), str(getattr(args, "fileslocation"))
        )
    )

    return True


def createOptimusPrimeViewsTransformers(gcpProjectName, bqDataset, view_name, view_query):
    # This function intents to create all views found in the opViews directory. The views creation must follow opConfig/transformers.json

    client = bigquery.Client()

    if gcpProjectName is None:
        # In case project_name is not provided in the arguments
        view_id = str(client.project) + "." + str(bqDataset) + "." + view_name
        gcpProjectName = str(client.project)
    else:
        # If project_name is provided in the arguments
        view_id = str(gcpProjectName) + "." + str(bqDataset) + "." + view_name

    # Creating the JOB to create view in Big Query
    view = bigquery.Table(view_id)

    # Extracting the view text and replacing the string ${dataset}/${project_name} by the proper dataset independent of case sensitive
    pattern = re.compile(re.escape("${dataset}"), re.IGNORECASE)
    view_query = pattern.sub(str(bqDataset), view_query)
    pattern = re.compile(re.escape("${project_name}"), re.IGNORECASE)
    view_query = pattern.sub(str(gcpProjectName), view_query)
    # source_id = 'optimusprime-migrations.consolidate_test.dbsummary'
    # view_query = f"SELECT pkey, dbid FROM `{source_id}`"

    view.view_query = view_query

    try:
        # Make an API request to create the view.
        view = client.create_table(view)
        print("Created {}: {}".format(view.table_type, str(view.reference)))
        print("\n")
    except Conflict as error:
        print("View {} already exists.\n".format(str(view.reference)))
        # view = client.update_table(view, ['view_query'])
        return False
    except:
        print("View {} count not be created. See DDL below:\n".format(str(view.reference)))
        print(view_query)
        return False

    return True


def createOptimusPrimeViewsFromOS(gcpProjectName, bqDataset):
    # This function intents to create all views found in the opViews directory. The views creation must follow opViews/<filename> order

    # print ('\nPreparing to create Optimus Prime SQL Views\n')

    # store all files found in the OS
    fileList = []

    # Searching for all matching files in the default views location
    filePattern = "opViews/optimus_createView*.sql"

    # List with all views to be created
    fileList = list_files(filePattern)

    if len(fileList) == 0:
        # print('\nWARNING: No views found to be created at expected location: {}. Please make sure you the location is correct.'.format(filePattern))
        # Returns False if cannot create views
        return False

    else:

        client = bigquery.Client()

        # Sorting list to make sure the proper view creation
        fileList.sort()

        # Looping to iterate all view files found in the OS to be created. Also, to extract the proper view name out of them.
        for viewFileName in fileList:

            # Extracting the proper view name to be created in Big Query based out of OS view filename
            view_name = str(get_obj_name_from_files(viewFileName, "__", 1)).replace(".sql", "")

            print("Preparing to process {} and create the view name {}".format(viewFileName, view_name))

            if gcpProjectName is None:
                # In case project_name is not provided in the arguments
                view_id = str(client.project) + "." + str(bqDataset) + "." + view_name
            else:
                # If project_name is provided in the arguments
                view_id = str(gcpProjectName) + "." + str(bqDataset) + "." + view_name

            # Creating the JOB to create view in Big Query
            view = bigquery.Table(view_id)

            # Extracting the view text and replacing the string ${dataset} by the proper dataset
            with open(viewFileName, "r") as view_content:
                view.view_query = view_content.read().replace("${dataset}", str(bqDataset))

            try:
                # Make an API request to create the view.
                view = client.create_table(view)
                print("Created {}: {}".format(view.table_type, str(view.reference)))
                print("\n")
            except Conflict as error:
                print("View {} already exists.\n".format(str(view.reference)))

        return True


def list_files(filePattern):
    # This function intends to get the name of all files in the OS and return a list of strings

    # Get all matching files and creates a list returning it
    return glob.glob(filePattern)


def importAllDataframeToBQ(
    args,
    gcpProjectName,
    bqDataset,
    transformersTablesSchema,
    dbAssessmentDataframes,
    transformersParameters,
    importresults,
):

    # Tracking tableNames Imported to Big Query
    tablesImported = {}

    if args.fromdataframe:

        print("\nPreparing to import DATAFRAMES to BigQuery\n")

        # Creating Hash Table with all expected table schemas to be imported
        tableSchemas = {}

        # Always AUTO because we never know the column order in which the dataframe will be
        # transformersTablesSchema = rules_engine.processSchemaDetection('AUTO',transformersTablesSchema, None, str(tableName).lower(), df)

        # tableSchemas = getBQJobConfig(transformersTablesSchema,'DATAFRAME')

        for tableName in dbAssessmentDataframes:

            print("\nThe dataframe {} is being imported to Big Query.".format(tableName))

            if str(tableName).lower() in transformersParameters["do_not_import"]:

                print("Table name {} is being SKPIPED accordingly with transformers.json do_not_import parameter")

                continue

            if str(tableName).lower() == "opkeylog":
                df = dbAssessmentDataframes[tableName]
                df["CMNT"] = transformersParameters["importcomment"]
                df["LOADTOBQDATE"] = ct
                df["JOBPARAMS"] = str(vars(args))

            # Import the given CSV fileName into
            sucessImport, importresults = importDataframeToBQ(
                gcpProjectName,
                bqDataset,
                str(tableName).lower(),
                tableSchemas,
                dbAssessmentDataframes[tableName],
                transformersParameters,
                args,
                importresults,
            )
            if sucessImport:
                tablesImported[str(tableName).lower()] = "IMPORTED_FROM_DATAFRAME"

        return True, tablesImported, importresults

    else:

        return False, tablesImported, importresults


def importDataframeToBQ(
    gcpProjectName,
    bqDataset,
    tableName,
    tableSchemas,
    df,
    transformersParameters,
    args,
    importresults,
):

    # Getting table schema
    try:

        # in case there is nothing to be imported
        if str(tableName).lower() in transformersParameters["do_not_import"]:

            return True

        # Creating Hash Table with all expected table schemas to be imported
        tableSchemas = {}
        transformersTablesSchemaDataframe = {}

        dfColumns = df.columns
        dfNewColumns = []

        # Changing column names that are not supported in Big Query.
        # Ideally this fix should be in the collection script
        for column in dfColumns:

            column = column.replace("(1)", "")
            column = column.replace("(X=5%)", "")
            column = column.replace("#", "")

            dfNewColumns.append(column)

        df.columns = dfNewColumns

        # Always AUTO because we never know the column order in which the dataframe will be
        transformersTablesSchemaDataframe = rules_engine.detect_schema(
            "FILLGAP",
            transformersTablesSchemaDataframe,
            None,
            str(tableName).lower(),
            df,
        )

        tableSchemas = get_bq_job_config(transformersTablesSchemaDataframe, "DATAFRAME")

        schema = tableSchemas[str(tableName).lower()]

    except KeyError:
        # In case there is not expected table schema found in getBQJobConfig function
        print('\nWARNING: The dataframe "{}" could not be imported to Big Query.'.format(tableName))
        print(
            'The table name "{}" cannot be imported because it does not have table schema in transformers.json. So, it will be skipped.\n'.format(
                tableName
            )
        )
        importresults = populate_summary(
            tableName,
            df,
            "importDataframeToBQ",
            "isFile",
            "fromimportDataframeToBQ",
            -1,
            importresults,
            args,
        )
        return False, importresults

    try:
        df = df.astype(str)
    except:
        print('\nWARNING: The dataframe "{}" could not be converted to STRING.'.format(tableName))

    if str(tableName).lower() == "opkeylog":
        # Construct a BigQuery client object with API Call to track Tool usage
        client = bigquery.Client(client_info=set_client_info.get_http_client_info())
    else:
        client = bigquery.Client()

    # Adding Project and Dataset based on arguments
    # table_id to the ID of the table to create.
    if gcpProjectName is not None:
        table_id = str(gcpProjectName) + "." + str(bqDataset) + "." + str(tableName)

    # In case project_name was passed as argument. Then, it tries to get the default project for the [service] account being used
    else:
        table_id = str(client.project) + "." + str(bqDataset) + "." + str(tableName)

    # Changed default to from WRITE_TRUNCATE to WRITE_APPEND in args.loadtype.
    write_disposition = str(args.loadtype).upper()
    schema_updateOptions = []
    file_format = bigquery.SourceFormat.CSV
    if str(tableName).lower() == "opkeylog":
        ## OpkeyLog is a load stats table so rows would be appended and if any schema change is there, the update of schema would be allowed
        schema_updateOptions = [bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]
        write_disposition = "WRITE_APPEND"

    job_config = bigquery.LoadJobConfig(
        # Specify a (partial) schema. All columns are always written to the
        # table. The schema is used to assist in data type definitions.
        schema=schema,
        schema_update_options=schema_updateOptions,
        # Optionally, set the write disposition. BigQuery appends loaded rows
        # to an existing table by default, but with WRITE_TRUNCATE write
        # disposition it replaces the table with the loaded data.
        write_disposition=write_disposition
        # ,
        # field_delimiter = ";",
        # source_format = file_format
    )

    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)  # Make an API request.
    job.result()  # Wait for the job to complete.

    table = client.get_table(table_id)  # Make an API request.
    print("Loaded {} rows and {} columns to {}".format(table.num_rows, len(table.schema), table_id))

    importresults = populate_summary(
        tableName,
        df,
        "importDataframeToBQ",
        "isFile",
        "fromimportDataframeToBQ",
        -1,
        importresults,
        args,
    )

    # Returns True if successfully
    return True, importresults


def add_details(fileName, args, params, table_header):
    df = pd.read_csv(
        fileName,
        sep=str(args.sep),
        skiprows=2,
        na_values="n/a",
        keep_default_na=True,
        skipinitialspace=True,
        names=table_header,
        index_col=False,
    )
    if params["import_comment"]:
        df["CMNT"] = params["import_comment"]
    df["LOADTOBQDATE"] = ct
    df["JOBPARAMS"] = str(vars(args))
    df.to_csv(fileName, index=False, sep=str(args.sep))
    line = ""
    with open(fileName, "r+", encoding="UTF-8") as f:
        content = f.read()
        f.seek(0, 0)
        f.write(line.rstrip("\r\n") + "\n" + content)


def import_all_csvs_to_bq(
    gcp_project_name,
    bq_dataset,
    fileList,
    transformersTablesSchema,
    skip_leading_rows,
    transformersParameters,
    args,
    import_results,
):
    # This function receives a list of files to import to Big Query, then it calls importCSVToBQ to import table/file by table/file

    print("\nPreparing to upload CSV files\n")

    # Creating Hash Table with all expected table schemas to be imported
    table_schemas = {}
    table_schemas = get_bq_job_config(transformersTablesSchema, "REGULAR")

    fileList.sort()

    # Getting the name of the target table_name to import the data based on the filename from OS
    for file_name in fileList:

        # Default Big Query Job Configurations for Optimus Prime CSV files
        auto_detect = "True"

        # Final table name from the CSV file names
        table_name = get_obj_name_from_files(file_name, "__", 1)

        doNotImportList = [table.strip().lower() for table in transformersParameters["do_not_import"]]

        if str(table_name).lower() == "opkeylog":
            # #skipLeadingRows=1
            tableHeaders = rules_engine.get_headers_from_config(str(table_name).lower(), transformersTablesSchema)
            tableHeader = [header.upper() for header in tableHeaders]
            add_details(file_name, args, transformersParameters, tableHeader)

        if table_name.lower() not in doNotImportList:

            # Import the given CSV fileName into
            print("\nThe filename {} is being imported to Big Query.".format(file_name))

            success_import, import_results = importCSVToBQ(
                gcp_project_name,
                bq_dataset,
                table_name,
                file_name,
                skip_leading_rows,
                auto_detect,
                table_schemas,
                args,
                import_results,
            )

        else:

            print(
                "\nThe filename {} is being SKIPPED accordingly with parameter {} from transformers.json.".format(
                    file_name, "do_not_import"
                )
            )

    return True, import_results


def importCSVToBQ(
    gcp_project_name,
    bq_dataset,
    table_name,
    file_name,
    skip_leading_rows,
    auto_detect,
    table_schemas,
    args,
    import_results,
):
    # This function will import the CSV file into the Big Query using the proper project.dataset.tablename
    # A Big Query Job is created for it

    # Getting table schema
    try:
        schema = table_schemas[table_name]
    except KeyError:
        # In case there is not expected table schema found in getBQJobConfig function
        print('\nWARNING: The filename "{}" could not be imported to Big Query.'.format(file_name))
        print(
            'The table name "{}" cannot be imported because it does not have table schema in transformers.json. So, it will be skipped.\n'.format(
                table_name
            )
        )
        return False

    if str(table_name).lower() == "opkeylog":
        # Construct a BigQuery client object with API Call to track Tool usage
        client = bigquery.Client(client_info=set_client_info.get_http_client_info(), project=gcp_project_name)
    else:
        # Construct a BigQuery client object.
        client = bigquery.Client(project=gcp_project_name)

    # Adding Project and Dataset based on arguments
    # table_id to the ID of the table to create.
    if gcp_project_name is not None:
        table_id = str(gcp_project_name) + "." + str(bq_dataset) + "." + str(table_name)

    # In case project_name was passed as argument. Then, it tries to get the default project for the [service] account being used
    else:
        table_id = str(client.project) + "." + str(bq_dataset) + "." + str(table_name)

    schema_update_options = []
    field_delimiter = str(args.sep)
    write_disposition = str(args.load_type).upper()

    if str(table_name).lower() == "opkeylog":
        ## OpkeyLog is a load stats table so rows would be appended
        # and if any schema change is there, the update of schema would be allowed
        schema_update_options = [bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION]

    # OP Internal Configuration Files
    elif str(table_name).lower() in (
        "optimusconfig_bms_machinesizes",
        "optimusconfig_network_to_gcp",
    ):
        write_disposition = "WRITE_TRUNCATE"
        field_delimiter = ","

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        skip_leading_rows=skip_leading_rows,
        schema_update_options=schema_update_options,
        # The source format defaults to CSV, so the line below is optional.
        source_format=bigquery.SourceFormat.CSV,
        field_delimiter=field_delimiter,
        write_disposition=write_disposition,
    )

    with open(file_name, "rb") as source_file:

        try:
            load_job = client.load_table_from_file(source_file, table_id, job_config=job_config)
        except Exception as e:
            print(
                '\n FAILED: Optimus Prime could not import the filename "{}" into "{}" because of the error "{}".\n'.format(
                    file_name, table_id, e
                )
            )

            print("   Table Schema = {}".format(schema))

            import_results = populate_summary(
                table_name,
                "isFile",
                "importDataframeToBQ",
                file_name,
                "fromimportCSVToBQ",
                -1,
                import_results,
                args,
            )

            return False, import_results

    try:
        load_job.result()  # Waits for the job to complete.
    except Exception as e:
        print(
            '\n FAILED: Optimus Prime could not import the filename "{}" into "{}" because of the error "{}".\n'.format(
                file_name, table_id, e
            )
        )
        import_results = populate_summary(
            table_name,
            "isFile",
            "importDataframeToBQ",
            file_name,
            "fromimportCSVToBQ",
            -1,
            import_results,
            args,
        )
        return False, import_results

    destination_table = client.get_table(table_id)  # Make an API request.
    print("Loaded {} rows into: {}".format(destination_table.num_rows, destination_table.reference))

    import_results = populate_summary(
        table_name,
        "isFile",
        "importDataframeToBQ",
        file_name,
        "fromimportCSVToBQ",
        destination_table.num_rows,
        import_results,
        args,
    )

    # returns True if processing is successfully
    return True, import_results


def get_table_ref(dataset, table_name, project_name):
    client = bigquery.Client(project=project_name)

    if project_name:
        return f"{project_name}.{dataset}.{table_name}"

    return f"{client.project}.{dataset}.{table_name}"


def get_obj_name_from_files(file_name, splitter_char, pos):
    # This function returns a string based on a string splitted(Created a list) by a given character. Then, it returns the desired index position of the list.

    # return fileName.split(splitterChar)[pos]
    splits = file_name.split(splitter_char)

    if len(splits) >= pos:

        return splits[pos]

    return None


def get_bq_job_config(table_schemas, job_type):

    bq_tables_job_config = {}

    for table_name in table_schemas:

        bq_tables_job_config[table_name] = []

        for schema_field in table_schemas[table_name]:

            if job_type == "REGULAR":

                bq_tables_job_config[table_name].append(
                    bigquery.SchemaField(str(schema_field[0]), str(schema_field[1]))
                )

            elif job_type == "DATAFRAME":

                # bqTablesJobConfig[tableName].append(bigquery.SchemaField(str(schemaField[0]).upper(), 'bigquery.enums.SqlTypeNames.' + str(schemaField[1])))
                bq_tables_job_config[table_name].append(
                    bigquery.SchemaField(str(schema_field[0]).upper(), str(schema_field[1]))
                )

    return bq_tables_job_config


def create_dataset(datasetName, gcpProjectName):
    # Always try to create the dataset

    # Construct a BigQuery client object.
    client = bigquery.Client(project=gcpProjectName)
    if gcpProjectName is None:
        # In case the user did NOT pass the project name in the arguments
        dataset_id = "{}.{}".format(client.project, datasetName)
    else:
        # In case tge use DID pass the project name in the arguments
        dataset_id = "{}.{}".format(gcpProjectName, datasetName)

    # Construct a full Dataset object to send to the API.
    dataset = bigquery.Dataset(dataset_id)

    # TODO(developer): Specify the geographic location where the dataset should reside.
    dataset.location = client.location

    # Send the dataset to the API for creation, with an explicit timeout.
    # Raises google.api_core.exceptions.Conflict if the Dataset already
    # exists within the project.
    try:
        dataset = client.create_dataset(dataset)  # Make an API request.
        print("Created dataset {}.{}".format(client.project, dataset.dataset_id))

    except Conflict:
        # If dataset already exists
        print("Dataset {} already exists.".format(dataset_id))


def delete_dataset(datasetName, gcpProjectName):

    # Construct a BigQuery client object.
    client = bigquery.Client()

    # Set dataset_id=datasetName to the ID of the dataset to create.
    if gcpProjectName is None:
        # In case the user did NOT pass the project name in the arguments
        dataset_id = "{}.{}".format(client.project, datasetName)
    else:
        # In case tge use DID pass the project name in the arguments
        dataset_id = "{}.{}".format(gcpProjectName, datasetName)

    # Construct a full Dataset object to send to the API.
    dataset = bigquery.Dataset(dataset_id)

    # TODO(developer): Specify the geographic location where the dataset should reside.
    dataset.location = client.location

    # Send the dataset to the API for creation, with an explicit timeout.
    # Raises google.api_core.exceptions.Conflict if the Dataset already
    # exists within the project.
    try:
        client.delete_dataset(dataset_id, delete_contents=True, not_found_ok=True)  # Make an API request.
        print("Deleted dataset {}".format(dataset_id))

    except Conflict:
        # If dataset already exists
        print("Failed to delete dataset {}.".format(dataset_id))


def insert_errors(invalid_files, op_df, gcp_project_name, bq_dataset):
    from google.cloud.exceptions import NotFound

    table_id = "operrors"
    try:
        pkey = op_df["PKEY"].iloc[0]
        bq_client = bigquery.Client()
        try:
            table = bq_client.get_table("{}.{}.{}".format(gcp_project_name, bq_dataset, table_id))
        except NotFound:
            schema = [
                bigquery.SchemaField("PKEY", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("LOADDATE", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("FILENAME", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("ERROR", "STRING", mode="REQUIRED"),
            ]
            table = bigquery.Table(gcp_project_name + "." + bq_dataset + "." + table_id, schema=schema)
            table = bq_client.create_table(table)  # Make an API request.
        rows = []
        for filename, error in invalid_files.items():
            basename = os.path.basename(filename)
            rows_to_insert = {
                "PKEY": pkey,
                "LOADDATE": str(ct),
                "FILENAME": basename,
                "ERROR": error,
            }
            rows.append(rows_to_insert)
        _ = bq_client.insert_rows_json(table, rows)
    except Exception as e:
        print(
            "\nWARNING: Issues while pushing Errors into operrors table with error ",
            e,
        )


def populate_summary(
    table_name,
    df,
    dataframe_or_not,
    invalid_files,
    bt_source,
    imported_rows,
    import_results,
    args,
):
    # Fuction to populate the importresults list which will be used to print using Beautiful Table
    # rowsimported of <0 is used to indicate a FAILED status
    tmp_dataframe = pd.DataFrame()

    if "opConfig/" in invalid_files:
        return import_results

    if bt_source == "invalidfiles":  # when called from runMain
        for file_name, error in invalid_files.items():
            tmp_dataframe = pd.DataFrame()
            tmp_dataframe_dict = {
                "Target Table": get_obj_name_from_files(file_name, "__", 1),
                "Distinct Pkey": get_obj_name_from_files(file_name, "__", 2),
                "Import Status": "FAILED",
                "Loaded rows": 0,
            }
            tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)
            if len(tmp_dataframe) > 0:
                import_results = pd.concat([import_results, tmp_dataframe], ignore_index=True, axis=0)
    else:
        if args.from_dataframe:  # when called from importDataframeToBQ
            if dataframe_or_not is not None:
                if "PKEY" in df.columns.to_list():
                    df.reset_index(drop=True, inplace=True)
                    group_by = df.groupby(["PKEY"]).size()
                    key_count = group_by.to_dict()
                    for key_name, key_name_rowcount in key_count.items():
                        tmp_dataframe = pd.DataFrame()
                        tmp_dataframe_dict = {
                            "Target Table": table_name,
                            "Distinct Pkey": key_name,
                            "Import Status": "SUCCESS",
                            "Loaded rows": key_name_rowcount,
                        }
                        tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)
                        if len(tmp_dataframe) > 0:
                            import_results = pd.concat([import_results, tmp_dataframe], ignore_index=True, axis=0)

        else:
            file_name = invalid_files  # when called from importCSVToBQ

            if "opdbt" not in file_name:
                if imported_rows >= 0:
                    if len(import_results) == 0:
                        tmp_dataframe = pd.DataFrame()
                        tmp_dataframe_dict = {
                            "Target Table": table_name,
                            "Distinct Pkey": get_obj_name_from_files(file_name, "__", 2),
                            "Import Status": "SUCCESS",
                            "Loaded rows": imported_rows,
                        }
                        tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)
                    else:
                        if (
                            table_name in import_results["Target Table"].values
                            and "SUCCESS" in import_results["Import Status"].values
                        ):
                            # this is needed as bq functions check for rows already loaded and not the new ones only
                            existing_rows = import_results[
                                import_results["Target Table"].str.contains(table_name)
                                & import_results["Import Status"].str.contains("SUCCESS")
                            ]["Loaded rows"].sum()
                            new_rows = imported_rows - existing_rows

                            tmp_dataframe = pd.DataFrame()
                            tmp_dataframe_dict = {
                                "Target Table": table_name,
                                "Distinct Pkey": get_obj_name_from_files(file_name, "__", 2),
                                "Import Status": "SUCCESS",
                                "Loaded rows": new_rows,
                            }
                            tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)
                        else:
                            tmp_dataframe = pd.DataFrame()
                            tmp_dataframe_dict = {
                                "Target Table": table_name,
                                "Distinct Pkey": get_obj_name_from_files(file_name, "__", 2),
                                "Import Status": "SUCCESS",
                                "Loaded rows": imported_rows,
                            }
                            tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)

                else:
                    tmp_dataframe = pd.DataFrame()
                    tmp_dataframe_dict = {
                        "Target Table": table_name,
                        "Distinct Pkey": get_obj_name_from_files(file_name, "__", 2),
                        "Import Status": "FAILED",
                        "Loaded rows": 0,
                    }
                    tmp_dataframe = tmp_dataframe.append(tmp_dataframe_dict, ignore_index=True)

                if len(tmp_dataframe) > 0:
                    import_results = pd.concat([import_results, tmp_dataframe], ignore_index=True, axis=0)

    return import_results


def print_results(importresults):
    # Fuction to print the import logs present in  btImportLogTable /btImportLogFinalTable

    # Create and load the output bt table
    import_log_final_table = BeautifulTable(maxwidth=300)
    import_log_final_table.columns.header = [
        "Target Table",
        "Distinct Pkey",
        "Import Status",
        "Loaded rows",
    ]

    # To group by table name, import status, count of distinct pkeys and sum of rows
    if not importresults.empty:
        import_results_agg = (
            importresults.groupby(["Target Table", "Import Status"])["Loaded rows"]
            .agg(["size", "sum"])
            .reset_index(drop=False)
        )
        import_results_final = import_results_agg.rename(columns={"size": "Distinct Pkey", "sum": "Loaded rows"})

        # convert float type to int type
        import_results_final["Loaded rows"] = import_results_final["Loaded rows"].astype(int)

        # swap for correcting to match the expected order of columns
        import_results_final = import_results_final[["Target Table", "Distinct Pkey", "Import Status", "Loaded rows"]]

        # insert into beautiful table
        for _, row in import_results_final.iterrows():
            import_log_final_table.rows.append(row)

    import_log_final_table.set_style(BeautifulTable.STYLE_BOX_ROUNDED)
    print("\n\n Import Completed....\n")
    print("\n Import Summary \n\n")
    print(import_log_final_table)