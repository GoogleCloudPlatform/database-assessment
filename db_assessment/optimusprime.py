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


import argparse
import logging
import sys
import warnings
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any, Dict

import pandas as pd

from db_assessment import import_db_assessment, rules_engine
from db_assessment.remote import run_remote

logger = logging.getLogger()
logger.setLevel(level=logging.INFO)

if TYPE_CHECKING:
    from .api import AppConfig

warnings.simplefilter(action="ignore", category=FutureWarning)


@dataclass
class RunConfig:
    parameters: Dict[str, Any]
    rules: Dict[str, Any]
    table_schemas = Dict[str, Any]


def run_main(args: "AppConfig") -> None:
    """Main program"""
    run_config: Dict[str, Any] = rules_engine.load_from_config(args.config_path)
    rules: Dict[str, Any] = run_config["rules"]
    run_parameters: Dict[str, Any] = run_config["parameters"]
    schema_config: Dict[str, Any] = run_config["table_schemas"]

    table_schema = None

    # For all cases in which those attributes are <> None it means
    #  the user wants to import data to Big Query
    # No need to further messaging for mandatory options because
    #  this is being done in argumentsParser function
    if args.dataset is not None and args.collection_id is not None:

        # This is broken needs to be fixed in upcoming versions
        if args.consolidate_logs:
            # It is True if no fatal errors were found
            import_db_assessment.consolidate_collection(
                args,
                table_schema,
            )

        # STEP 1: Import customer database assessment data

        # Optimus Prime Search Pattern to find the target
        # CSV files to be processed
        # The default location will be dbResults if not overwritten
        # by the argument --files-location
        file_search_pattern = (
            f"{args.files_location}/*{args.collection_id.replace(' ', '')}.csv"
        )

        # Append files_location if there are filter_by_sql_version
        # and/or filter_by_db_version flag
        if args.filter_by_sql_version:
            file_search_pattern = file_search_pattern.replace(
                f"{args.files_location}/",
                f"{args.files_location}/*-{args.filter_by_sql_version}*",
            )

        file_list = []
        if args.filter_by_db_version:
            for db_version in args.filter_by_db_version.split(","):
                db_version = db_version.replace(".", "")
                file_search_pattern = file_search_pattern.replace(
                    f"{args.files_location}/*",
                    f"{args.files_location}/*__{db_version}*",
                )

                file_matches = import_db_assessment.list_files(
                    file_search_pattern,
                )
                file_list.extend(file_matches)
        else:
            # Getting a list of files from OS based on the pattern provided
            # This is the default directory to have all customer database
            # results from oracle_db_assessment.sql
            file_list.extend(
                import_db_assessment.list_files(file_search_pattern),
            )

        # In case there is no matching file in the OS
        if len(file_list) == 0:
            logger.fatal(
                "ERROR: There is no matching CSV file found to be processed using: %s",  # pylint: disable=[line-too-long]
                file_search_pattern,
            )
            sys.exit()

        #  Make sure there are not 11.2 or 11.1 database versions being imported along with other database versions.
        db_versions_list = set([f.split("__")[2].split("_")[0] for f in file_list])
        outliers = len(
            [version for version in db_versions_list if version not in ["111", "112"]]
        )
        if ("111" in db_versions_list or "112" in db_versions_list) and outliers > 0:
            sys.exit(
                '\nERROR:  Importing other versions along with 11.1 and 11.2 is not supported. Please use flag --filter-by-db-version to filter database versions, For example: --filter-by-db-version "12.1,12.2,18.0,19.1"\n'
            )

        sqlversionslist = set([f.split("__")[2].split("_")[1] for f in file_list])
        if len(sqlversionslist) > 1:
            sys.exit(
                '\nERROR:  Importing multiple SQL versions is not supported. Please use flag --filter-by-sql-version to filter SQL versions, For example: --filter-by-sql-version 2.0.3"\n'
            )

        # Getting file pattern for find config files in the OS to be imported
        csvFilesLocationPatternOPConfig = "db_assessment/opConfig/*.csv"

        # Getting a list of files from OS based on the pattern provided
        fileListOPConfig = import_db_assessment.list_files(
            csvFilesLocationPatternOPConfig
        )

        # Variable to track the collection id. To be used mostly when new CSV files are generated from processing rules
        collectionKey = import_db_assessment.getObjNameFromFiles(
            str(file_list[0]), "__", 2
        )
        run_parameters["collectionKey"] = collectionKey

        # Verify if the script has any version on it (only old script versions should not have 3 parts)
        if args.db_version is not None:
            run_parameters["db_version"] = str(args.db_version)
        elif (
            len(collectionKey.split("_")) >= 3 and args.db_version is None
        ):  # bug #23. Changed == to >=.
            run_parameters["db_version"] = import_db_assessment.getObjNameFromFiles(
                collectionKey, "_", 0
            )
        else:
            logger.fatal(
                "FATAL ERROR: Please use --db-version and --collection-version."
                " (i.e --db-version 122 --collection-version 2.0.3)"
            )
            sys.exit()

        if args.import_comment is not None:
            run_parameters["import_comment"] = args.import_comment

        if len(collectionKey.split("_")) >= 3:  # bug #23. Changed == to >=.
            run_parameters[
                "collection_version"
            ] = import_db_assessment.getObjNameFromFiles(collectionKey, "_", 1)
        else:
            run_parameters["collection_version"] = args.collection_version

        # If this value is set it has precedence over everything else
        if args.collection_version != "0.0.0":
            run_parameters["collection_version"] = args.collection_version

        try:
            # Automatically try to select the right file separator accordingly with the SQL Script version
            if int(str(run_parameters["collection_version"]).replace(".", "")) < 205:
                args.sep = ","
        except Exception as e:
            logger.warning("non-fatal exception occurred: %s", e.args)
        logger.info("Source Database Version: %s: {}\n", run_parameters["db_version"])

        logger.info(
            "Source Database Version: %s Collection Script Version: %s",
            run_parameters["db_version"],
            run_parameters["collection_version"],
        )
        try:
            # Adjusting the table_schemas from transformers.json accordingly with the database version
            for db_version in schema_config[
                run_parameters["collection_version"]
            ].keys():

                if run_parameters["db_version"] in db_version:
                    table_schema = schema_config[run_parameters["collection_version"]][
                        db_version
                    ]

            # If we could not find any matching for tableSchemas
            if table_schema is None:
                raise KeyError
        except KeyError:
            logger.fatal(
                "FAILURE: Optimus Prime could not find in transformers.json"
                "matching for table schema configuration for "
                "collection_version=%s and db_version=%s",
                run_parameters["collection_version"],
                run_parameters["db_version"],
            )
            sys.exit()

        # Import the CSV files into Big Query
        gcpProjectName = args.project_name
        bqDataset = str(args.dataset)

        # Delete the dataset before importing new data
        if args.delete_dataset:
            if args.project_name is not None:
                import_db_assessment.deleteDataSet(bqDataset, gcpProjectName)
            else:
                logger.fatal(
                    "WARNING: The database %s will not be deleted "
                    "because the option --project-name is omitted. "
                    "Please try again either "
                    "providing --project-name OR removing -delete_dataset.",
                    args.delete_dataset,
                )
                sys.exit()

        # Create the dataset to import the CSV data
        import_db_assessment.createDataSet(bqDataset, gcpProjectName)

        # STEP: Processing parameters
        # which create internal variables(run_parameters)
        # to be used in later stages

        # ####transformerParameterResults, run_parameters = rules_engine.runRules(rules, None, None)

        # STEP: Loading all CSV files in memory into dataframes

        dbAssessmentDataframes = {}
        invalidfiles = {}
        (dbAssessmentDataframes, table_schema,) = rules_engine.getAllDataFrames(
            file_list,
            1,
            collectionKey,
            args,
            table_schema,
            dbAssessmentDataframes,
            run_parameters,
            invalidfiles,
            args.skip_validations,
        )
        (dbAssessmentDataframes, table_schema,) = rules_engine.getAllDataFrames(
            fileListOPConfig,
            0,
            collectionKey,
            args,
            table_schema,
            dbAssessmentDataframes,
            run_parameters,
            invalidfiles,
            args.skip_validations,
        )

        # STEP: Reshape Dataframes when necessary based on the run_parameters

        (
            dbAssessmentDataframes,
            file_list,
            table_schema,
            rulesAlreadyExecuted,
        ) = rules_engine.getAllReShapedDataframes(
            dbAssessmentDataframes,
            table_schema,
            run_parameters,
            rules,
            args,
            collectionKey,
            file_list,
        )

        # STEP: Run rules engine

        (
            transformerParameterResults,
            transformersRulesVariables,
            file_list,
            dbAssessmentDataframes,
        ) = rules_engine.run_rules(
            "1",
            rules,
            dbAssessmentDataframes,
            None,
            args,
            collectionKey,
            table_schema,
            file_list,
            rulesAlreadyExecuted,
            run_parameters,
            gcpProjectName,
            bqDataset,
        )

        # STEP: Import ALL data to Big Query
        # Local Variable store to avoid Global parameters
        importresults = pd.DataFrame()

        # Eliminating duplicated entries from transformers.json processing
        file_list = list(set(file_list))
        if len(invalidfiles) > 0:
            print("Below are Invalid Files \n")
            [print(key, ":", value) for key, value in invalidfiles.items()]
            file_list = [file for file in file_list if file not in invalidfiles.keys()]
            ## Insert Invalid Files to BQ
            if "OPKEYLOG" in dbAssessmentDataframes.keys():
                op_df = dbAssessmentDataframes["OPKEYLOG"]
                import_db_assessment.insertErrors(
                    invalidfiles, op_df, gcpProjectName, bqDataset
                )
                importresults = import_db_assessment.populateBT(
                    "notabname",
                    "nodataframe",
                    "yes",
                    invalidfiles,
                    "invalidfiles",
                    -1,
                    importresults,
                    args,
                )

        if args.from_dataframe:

            (
                sucessImported,
                tablesImported,
                importresults,
            ) = import_db_assessment.importAllDataframeToBQ(
                args,
                gcpProjectName,
                bqDataset,
                table_schema,
                dbAssessmentDataframes,
                run_parameters,
                importresults,
            )

        else:

            # Import the CSV data found in the OS
            sucessImported, importresults = import_db_assessment.importAllCSVsToBQ(
                gcpProjectName,
                bqDataset,
                file_list,
                table_schema,
                2,
                run_parameters,
                args,
                importresults,
            )
            # Import all Optimus Prime CSV configutation
            sucessImported, importresults = import_db_assessment.importAllCSVsToBQ(
                gcpProjectName,
                bqDataset,
                fileListOPConfig,
                table_schema,
                1,
                run_parameters,
                args,
                importresults,
            )

        (
            transformerParameterResults,
            transformersRulesVariables,
            file_list,
            dbAssessmentDataframes,
        ) = rules_engine.run_rules(
            "2",
            rules,
            dbAssessmentDataframes,
            None,
            args,
            collectionKey,
            table_schema,
            file_list,
            rulesAlreadyExecuted,
            run_parameters,
            gcpProjectName,
            bqDataset,
        )

        # Create Optimus Prime Views
        import_db_assessment.createOptimusPrimeViewsFromOS(gcpProjectName, bqDataset)

        # Call BT for import summary table
        import_db_assessment.printBTResults(importresults)
        print("\n\n Thank YOU for using Optimus Prime!\n\n")


def parse_arguments():
    """Parse command line arguments"""
    # function to handle all arguments to be used in cli mode
    # for this code and enforces mandatory options
    # Creating an argparser object
    parser = argparse.ArgumentParser()

    # Name of dataset to be created and have the data imported
    parser.add_argument(
        "--dataset",
        type=str,
        default=None,
        help=(
            "name of the Big Query dataset to import all CSV files. "
            "If do not exists it will be created if exists the data is appended"
        ),
    )

    # GCP project name to be used with the dataset
    parser.add_argument(
        "--project-name",
        type=str,
        default=None,
        help=("Google cloud project name for the BigQuery data"),
    )

    # OS csv files location to be imported to Big Query
    parser.add_argument(
        "--files-location",
        type=str,
        default="dbResults",
        help="optimus prime files location to be imported",
    )

    # OS csv files location to be imported to Big Query
    parser.add_argument(
        "--config-path",
        type=str,
        default="db_assessment/opConfig/transformers.json",
        help="location of transformers.json file with all parameters and rules",
    )

    # Optimus collection ID is the number in the final part of the generated CSV files. For example: dbResults/opdb_dbfeatures_ol79-orcl-db02.ORCLCDB.ORCLCDB.180603.csv. Collection ID is: 180603
    parser.add_argument(
        "--collection-id",
        type=str,
        default=None,
        help="optimus prime collection id from CSV files OR 'consolidate' for consolidated logs",
    )

    # Separator for the logs being processed
    parser.add_argument(
        "--sep",
        type=str,
        default=";",
        help="separator string in the files to be processed. The default is: ; (semicolon)",
    )

    parser.add_argument(
        "--db-version", type=str, default=None, help="database version to be processed"
    )

    parser.add_argument(
        "--collection-version",
        type=str,
        default="0.0.0",
        help="script collection version used",
    )

    parser.add_argument(
        "--schema-detection",
        type=str,
        default="FILLGAP",
        help="How Optimus Prime will handle table schemas to be imported to Big Query",
    )
    # Auto: Uses the columns found in the CSV file to import the data to BQ
    # Manual: Uses the configuration file from JSON
    # FillGaps: Uses manual and whenever a schema is missing then we use Auto for that

    # If this is present in the command line it will take value as true otherwise it will always be false
    parser.add_argument(
        "-d",
        "--delete-dataset",
        default=False,
        help="Delete dataset before importing new data. WARNING: It will delete all data in the dataset!",
        action="store_true",
    )

    parser.add_argument(
        "--load-type",
        type=str,
        default="WRITE_APPEND",
        help="Choose the BQ Load Type. Options are: WRITE_TRUNCATE, WRITE_APPEND and WRITE_EMPTY. The WRITE_APPEND is the default option.",
    )

    parser.add_argument(
        "--from-dataframe",
        default=False,
        help="Import dataframes to Big Query instead of CSV files.",
        action="store_true",
    )

    parser.add_argument(
        "--consolidate-dataframes",
        default=False,
        help="Consolidate CSV files before importing.",
        action="store_true",
    )

    parser.add_argument(
        "--remote", default=False, help="Leverage remote API", action="store_true"
    )

    parser.add_argument(
        "--remote-url",
        type=str,
        default="https://op-api-3qhhvv7zvq-uc.a.run.app",
        help="Leverage remote API",
    )

    # Consolidates different collection IDs found in the OS (dbResults/*log) into a single CSV per file type.
    # For example: dbResults has 52 files. Meaning, 2 collection IDs (each one has 26 different file types).
    # After the consolidation it produces 26 *consolidatedlogs.csv which would have data from both collection IDs
    parser.add_argument(
        "-cl",
        "--consolidate-logs",
        default=False,
        help="consolidate all CSV files opdb*log found in dbResults/ directory",
        action="store_true",
    )

    # Increase logging output level
    parser.add_argument(
        "-v", "--verbose", help="increase output verbosity", action="store_true"
    )

    parser.add_argument(
        "--import-comment", type=str, default="", help="Comment for the Import"
    )

    parser.add_argument(
        "--filter-by-db-version",
        type=str,
        default="",
        help="To import only specific db version",
    )
    parser.add_argument(
        "--filter-by-sql-version",
        type=str,
        default="",
        help="To import only specific SQL version",
    )
    parser.add_argument(
        "--skip-validations",
        default=False,
        help="To skip all the file Validations",
        action="store_true",
    )

    # Execute the parse_args() method. Variable args is a namespace type
    args = parser.parse_args()

    # If not using -cl flag
    if args.consolidate_logs is False:

        # In case there is not dataset parameter set or with valid content in the arguments
        if args.dataset is None or args.dataset == "":
            sys.exit(
                "\nERROR: The parameter -dataset cannot be omitted and it must have a valid name.\n"
            )

        # In case project name/project id is not provided
        elif args.project_name is None:
            print(
                "\nWARNING: Google Cloud project name not provided. Optimus Prime will try to get it automatically from Google Big Query API call.\n"
            )

        # In case optimus collection id is omitted
        elif args.collection_id is None:
            sys.exit(
                "\nERROR: The parameter -collectionid cannot be omitted. Please provide the collection id from CSV files.\n"
            )

    # Returns a namespace object with all arguments and its values
    return args


def main():
    args = parse_arguments()

    if args.remote:
        run_remote(args)
    else:
        # Call main function
        run_main(args)


if __name__ == "__main__":

    main()
