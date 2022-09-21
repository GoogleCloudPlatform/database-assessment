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

import json
import logging
import os
import warnings
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Union

import numpy as np
import pandas as pd

from db_assessment import import_db_assessment

if TYPE_CHECKING:
    from .api import AppConfig
warnings.simplefilter("error", pd.errors.ParserWarning)
warnings.simplefilter(action="ignore", category=FutureWarning)

logger = logging.getLogger()


def coerce_data_type(
    rule: Dict[str, Any]
) -> Optional[Union[Any, List[str], str, float]]:
    """Coerce data type from config

    Convert the JSON fields into variables like dictionaries,
     lists, string and numbers and return it"""

    if str(rule["action_details"]["datatype"]).upper() == "DICTIONARY":
        return json.loads(str(rule["action_details"]["value"]).strip())
    if str(rule["action_details"]["datatype"]).upper() == "LIST":
        # For Lists it is expected to be separated by comma
        return str(rule["action_details"]["value"]).split(",")
    if str(rule["action_details"]["datatype"]).upper() == "STRING":
        # For strings we just need to carry out the content
        return str(rule["action_details"]["value"])
    if str(rule["action_details"]["datatype"]).upper() == "NUMBER":
        # For number we are casting it to float
        return float(rule["action_details"]["value"])
    return None


def run_rules(
    executionGroup,
    transformerRules,
    dataframes,
    singleRule,
    args: "AppConfig",
    collectionKey,
    transformersTablesSchema,
    fileList,
    rulesAlreadyExecuted,
    transformersParameters,
    gcpProjectName,
    bqDataset,
):

    # Variable to keep track of rules executed and its results and status
    transformerResults = {}
    # Variable to keep track and make available all the variables from the JSON file
    transformersRulesVariables = {}

    # Standardize Statuses
    # Executed
    EXECUTEDSTATUS = "EXECUTED"
    FAILEDSTATUS = "FAILED"
    SKIPPEDSTATUS = "SKIPPED"

    if singleRule:
        # If parameter is set then we will run only 1 rule
        sorted_keys = []
        sorted_keys.append(singleRule)
    else:
        # Getting ordered list of keys by priority to iterate over the dictionary
        sorted_keys = sorted(
            transformerRules, key=lambda x: (transformerRules[x]["priority"])
        )

    # Looping on ALL rules from transformers.json
    for ruleItem in sorted_keys:

        stringExpression = getParsedRuleExpr(
            transformerRules[ruleItem]["action_details"]["expr1"]
        )
        if_errorExpression = getParsedRuleExpr(
            transformerRules[ruleItem]["action_details"]["if_error"]
        )

        if str(transformerRules[ruleItem]["status"]).upper() == "ENABLED":

            if (
                str(transformerRules[ruleItem]["execution_group"]).upper()
                == str(executionGroup).upper()
            ):

                if int(
                    str(transformersParameters["db_version"]).replace(".", "")[:3]
                ) in range(
                    int(
                        str(transformerRules[ruleItem]["min_db_version"]).replace(
                            ".", ""
                        )[:3]
                    ),
                    int(
                        str(transformerRules[ruleItem]["max_db_version"]).replace(
                            ".", ""
                        )[:3]
                    )
                    + 1,
                ):

                    if int(
                        str(transformersParameters["collection_version"]).replace(
                            ".", ""
                        )[:3]
                    ) in range(
                        int(
                            str(
                                transformerRules[ruleItem]["min_sql_script_version"]
                            ).replace(".", "")[:3]
                        ),
                        int(
                            str(
                                transformerRules[ruleItem]["max_sql_script_version"]
                            ).replace(".", "")[:3]
                        )
                        + 1,
                    ):

                        if ruleItem not in rulesAlreadyExecuted:

                            print(
                                '\nProcessing rule item: "{}"\nPriority: "{}"'.format(
                                    ruleItem, transformerRules[ruleItem]["priority"]
                                )
                            )

                            if (
                                str(
                                    transformerRules[ruleItem]["action_details"]["type"]
                                ).upper()
                                == "VARIABLE"
                                and str(
                                    transformerRules[ruleItem]["action_details"][
                                        "action"
                                    ]
                                ).upper()
                                == "CREATE"
                            ):
                                # transformers.json asking to create a variable which is a dictionary

                                try:
                                    transformerResults[ruleItem] = {
                                        "Status": EXECUTEDSTATUS,
                                        "Result Value": coerce_data_type(
                                            transformerRules[ruleItem]
                                        ),
                                    }
                                    transformersRulesVariables[
                                        transformerRules[ruleItem]["action_details"][
                                            "varname"
                                        ]
                                    ] = transformerResults[ruleItem]["Result Value"]

                                except:
                                    # In case of any issue the rule will be marked as FAILEDSTATUS
                                    transformerResults[ruleItem] = {
                                        "Status": FAILEDSTATUS,
                                        "Result Value": None,
                                    }
                                    transformersRulesVariables[
                                        transformerRules[ruleItem]["action_details"][
                                            "varname"
                                        ]
                                    ] = None

                            elif (
                                str(
                                    transformerRules[ruleItem]["action_details"]["type"]
                                ).upper()
                                in ("NUMBER", "FREESTYLE")
                                and str(
                                    transformerRules[ruleItem]["action_details"][
                                        "action"
                                    ]
                                ).upper()
                                == "ADD_OR_UPDATE_COLUMN"
                            ):
                                # transformers.json asking to add a column that is type number meaning it can be a calculation and the column to be added is NUMBER too

                                # Where the result of expr1 will be saved initially
                                dfTargetName = transformerRules[ruleItem][
                                    "action_details"
                                ]["dataframe_name"]
                                columnTargetName = transformerRules[ruleItem][
                                    "action_details"
                                ]["column_name"]
                                ruleCondition = True

                                try:
                                    ruleConditionString = str(
                                        transformerRules[ruleItem]["action_details"][
                                            "ifcondition1"
                                        ]
                                    )
                                except KeyError:
                                    ruleConditionString = None

                                # In case ifcondition1 (transformers.json) is set for the rule
                                if (
                                    ruleConditionString is not None
                                    and ruleConditionString != ""
                                ):

                                    try:
                                        ruleCondition = eval(ruleConditionString)
                                        print(
                                            "ruleCondition = {}".format(ruleCondition)
                                        )
                                    except:
                                        print(
                                            '\n Error processing ifcondition1 "{}" for rule "{}". So, this rule will be skipped.\n'.format(
                                                ruleConditionString, ruleItem
                                            )
                                        )
                                        continue

                                if not ruleCondition:
                                    print(
                                        'WARNING: This rule "{}" will be skipped because of "ifcondition1" from transformers.json is FALSE.'.format(
                                            ruleItem
                                        )
                                    )
                                    continue

                                try:
                                    dataframes[str(dfTargetName).upper()][
                                        str(columnTargetName).upper()
                                    ] = execStringExpression(
                                        stringExpression, if_errorExpression, dataframes
                                    )
                                    df = dataframes[str(dfTargetName).upper()]
                                except KeyError:
                                    print(
                                        '\n WARNING: The rule "{}" could not be executed because the variable "{}" used in the transformers.json could not be found.\n'.format(
                                            ruleItem, str(dfTargetName).upper()
                                        )
                                    )
                                    continue

                                newTableName = str(
                                    transformerRules[ruleItem]["action_details"][
                                        "target_dataframe_name"
                                    ]
                                ).lower()
                                fileName = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + newTableName
                                    + "__"
                                    + collectionKey
                                )

                                (
                                    resCSVCreation,
                                    transformersTablesSchema,
                                ) = createCSVFromDataframe(
                                    df,
                                    transformerRules[ruleItem]["action_details"],
                                    args,
                                    fileName,
                                    transformersTablesSchema,
                                    newTableName,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[str(newTableName).upper()] = df

                                if resCSVCreation:
                                    # If CSV creation was successfully then we will add this to the list of files to be imported
                                    fileList.append(fileName)

                            elif (
                                str(
                                    transformerRules[ruleItem]["action_details"]["type"]
                                ).upper()
                                == "FREESTYLE"
                                and str(
                                    transformerRules[ruleItem]["action_details"][
                                        "action"
                                    ]
                                ).upper()
                                == "CREATE_OR_REPLACE_DATAFRAME"
                            ):
                                #

                                df = execStringExpression(
                                    stringExpression, if_errorExpression, dataframes
                                )

                                if df is None:
                                    print(
                                        '\n WARNING: The rule "{}" could not be executed because the expression "{}" used in the transformers.json could not be executed.\n'.format(
                                            ruleItem, stringExpression
                                        )
                                    )
                                    continue

                                newTableName = str(
                                    transformerRules[ruleItem]["action_details"][
                                        "dataframe_name"
                                    ]
                                ).lower()
                                fileName = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + newTableName
                                    + "__"
                                    + collectionKey
                                )

                                (
                                    resCSVCreation,
                                    transformersTablesSchema,
                                ) = createCSVFromDataframe(
                                    df,
                                    transformerRules[ruleItem]["action_details"],
                                    args,
                                    fileName,
                                    transformersTablesSchema,
                                    newTableName,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[
                                    str(
                                        transformerRules[ruleItem]["action_details"][
                                            "dataframe_name"
                                        ]
                                    ).upper()
                                ] = df

                                if resCSVCreation:
                                    # If CSV creation was successfully then we will add this to the list of files to be imported
                                    fileList.append(fileName)

                            elif (
                                str(
                                    transformerRules[ruleItem]["action_details"]["type"]
                                ).upper()
                                == "FREESTYLE"
                                and str(
                                    transformerRules[ruleItem]["action_details"][
                                        "action"
                                    ]
                                ).upper()
                                == "FREESTYLE"
                            ):

                                try:
                                    eval(stringExpression)
                                except KeyError:
                                    print(
                                        '\n WARNING: The rule "{}" could not be executed because the expr1 "{}" used in the transformers.json could not be executed.\n'.format(
                                            ruleItem, stringExpression
                                        )
                                    )
                                    continue

                                newTableName = str(
                                    transformerRules[ruleItem]["action_details"][
                                        "target_dataframe_name"
                                    ]
                                ).lower()
                                fileName = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + newTableName
                                    + "__"
                                    + collectionKey
                                )

                                (
                                    resCSVCreation,
                                    transformersTablesSchema,
                                ) = createCSVFromDataframe(
                                    df,
                                    transformerRules[ruleItem]["action_details"],
                                    args,
                                    fileName,
                                    transformersTablesSchema,
                                    newTableName,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[str(newTableName).upper()] = df

                                if resCSVCreation:
                                    # If CSV creation was successfully then we will add this to the list of files to be imported
                                    fileList.append(fileName)

                            elif (
                                str(
                                    transformerRules[ruleItem]["action_details"]["type"]
                                ).upper()
                                == "CREATE VIEW"
                                and str(
                                    transformerRules[ruleItem]["action_details"][
                                        "action"
                                    ]
                                ).upper()
                                == "EXECUTE_SQL"
                            ):

                                view_name = transformerRules[ruleItem][
                                    "action_details"
                                ]["target_object_name"]
                                view_sql_query = transformerRules[ruleItem][
                                    "action_details"
                                ]["expr1"]
                                view_sql_query = "".join(view_sql_query)

                                import_db_assessment.createOptimusPrimeViewsTransformers(
                                    gcpProjectName, bqDataset, view_name, view_sql_query
                                )

                    else:

                        print(
                            '\n    The rule "{}" is being skipped because of the Optimus Prime SQL Version is {} and not eligible for this rule based on transformers.json configuration file.\n'.format(
                                str(ruleItem),
                                str(
                                    transformersParameters["collection_version"]
                                ).replace(".", "")[:3],
                            )
                        )
                        transformerResults[ruleItem] = {
                            "Status": SKIPPEDSTATUS,
                            "Result Value": "Due to Optimus Prime SQL Version configurarion on transformers.json",
                        }

                else:

                    print(
                        '\n    The rule "{}" is being skipped because of the Database Version is {} and not eligible for this rule based on transformers.json configuration file.\n'.format(
                            str(ruleItem),
                            str(transformersParameters["db_version"]).replace(".", "")[
                                :3
                            ],
                        )
                    )
                    transformerResults[ruleItem] = {
                        "Status": SKIPPEDSTATUS,
                        "Result Value": "Due to the Database Version configurarion on transformers.json",
                    }
            else:
                # print ('\n    The rule "{}" is being skipped because it belongs to a different EXECUTION GROUP based on transformers.json configuration file.\n'.format(str(ruleItem)))
                transformerResults[ruleItem] = {
                    "Status": SKIPPEDSTATUS,
                    "Result Value": "Due to the EXECUTION GROUP configurarion on transformers.json",
                }

        else:
            print(
                '\n    The rule "{}" is being skipped because it is NOT ENABLED based on transformers.json configuration file.\n'.format(
                    str(ruleItem)
                )
            )
            transformerResults[ruleItem] = {
                "Status": SKIPPEDSTATUS,
                "Result Value": "Due to the STATUS configurarion on transformers.json",
            }

    return transformerResults, transformersRulesVariables, fileList, dataframes


def execStringExpression(str_expression, if_error_expression, dataframes):

    try:
        res = eval(str_expression)
    except Exception:
        try:
            res = eval(if_error_expression)
        except Exception:
            res = None

    return res


def getParsedRuleExpr(ruleExpr):
    # Function to get a clean string to be executed in eval function. The input is a string with many components separated by ; coming from transformers.json

    ruleComponents = []
    ruleComponents = str(ruleExpr).split(";")

    finalExpression = ""

    for ruleItem in ruleComponents:

        ruleItem = ruleItem.strip()

        finalExpression = str(finalExpression) + str(ruleItem) + " "

    return finalExpression


def load_from_config(config_path: str):
    with open(config_path, encoding="UTF-8") as f:
        return json.load(f)


def parse_data(
    csv_filename: str,
    table_name: str,
    skip_rows: int,
    args: "AppConfig",
    transformersTablesSchema,
):
    """Read CSV files from OS and turn it into a dataframe"""

    paramCleanDFHeaders = False
    paramGetHeadersFromConfig = True

    # Configuration files always will be ,
    if "opConfig" in csv_filename:
        fileSeparator = ","
    else:
        fileSeparator = args.sep

    try:

        if paramGetHeadersFromConfig:

            if transformersTablesSchema.get(table_name):

                try:

                    tableHeaders = get_headers_from_config(
                        table_name, transformersTablesSchema
                    )
                    tableHeaders = [header.upper() for header in tableHeaders]
                    # df = pd.read_csv(csvFileName, skiprows=skipRows+1, header=None, names=tableHeaders, keep_default_na=False, na_filter= False)
                    df = pd.read_csv(
                        csv_filename,
                        skiprows=skip_rows + 1,
                        sep=str(fileSeparator),
                        header=None,
                        names=tableHeaders,
                        na_values="n/a",
                        keep_default_na=True,
                        skipinitialspace=True,
                    )

                except Exception:

                    print(
                        "\nThe filename {} for the table {} could not be imported using the column names {}.\n".format(
                            csv_filename, table_name, tableHeaders
                        )
                    )
                    paramCleanDFHeaders = True
                    # df = pd.read_csv(csvFileName, skiprows=skipRows, keep_default_na=False, na_filter= False)
                    df = pd.read_csv(
                        csv_filename,
                        sep=str(fileSeparator),
                        skiprows=skip_rows,
                        na_values="n/a",
                        keep_default_na=True,
                        skipinitialspace=True,
                    )

            else:

                # df = pd.read_csv(csvFileName, skiprows=skipRows, keep_default_na=False, na_filter= False)
                df = pd.read_csv(
                    csv_filename,
                    sep=str(fileSeparator),
                    skiprows=skip_rows,
                    na_values="n/a",
                    keep_default_na=True,
                    skipinitialspace=True,
                )

        # Removing index from dataframe
        df.reset_index(drop=True, inplace=True)

        # In case we need to clean some headers from dataframe
        if paramCleanDFHeaders:
            column_list = clean_csv_headers(df.columns.values.tolist()).split(",")
            df.columns = [column.strip() for column in column_list]

    except Exception:
        print("\nThe filename {} is most likely empty.\n".format(csv_filename))
        return False

    return df


def get_headers_from_config(tableName, transformersTablesSchema):

    tableConfig = transformersTablesSchema.get(tableName)

    tableHeaders = [header[0] for header in tableConfig]

    return tableHeaders


def getAllDataFrames(
    fileList,
    skipRows,
    collectionKey,
    args: "AppConfig",
    transformersTablesSchema,
    dbAssessmentDataframes,
    transformersParameters,
    invalidfiles,
    skipvalidations,
):
    # Fuction to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.
    # This function returns a dictionary with dataframes from CSVs

    # Hash table to store dataframes after being loaded from CSVs
    dataframes = dbAssessmentDataframes

    fileList.sort()
    for fileName in fileList:

        # Verifying if the file is a file that came from the SQL Script or is this is a result of a previous execution from transformers.json in which a file had been saved. I.E: Reshaped Dataframes
        collectionType = import_db_assessment.getObjNameFromFiles(
            str(fileName), "__", 0
        )
        collectionType = collectionType.split("/")[-1]

        if collectionType == "opdbt":
            # This file is not from SQL Script. Meaning this is a file generated by Optimus Prime in a prior execution. Skipping CSV files that are result of a previous transformation execution

            continue

        # Final table name from the CSV file names
        tableName = import_db_assessment.getObjNameFromFiles(fileName, "__", 1)

        if str(tableName).lower() in transformersParameters["do_not_import"]:

            print(
                "\n This table name {} for filename {} is being SKIPPED due to do_not_import parameter in transformers.json configuration file".format(
                    tableName, fileName
                )
            )

            continue

        print("\n Processing {} into a dataframe {}".format(fileName, tableName))

        # Validate the CSV file
        tableHeaders = get_headers_from_config(tableName, transformersTablesSchema)
        tableHeader = [header.upper() for header in tableHeaders]
        if not skipvalidations:
            fileError = validate_csv(fileName, tableHeader, args)
            if fileError is not None:
                basename = os.path.basename(fileName)
                print(
                    "File {} is skipped because of error -> {} ".format(
                        basename, fileError
                    )
                )
                invalidfiles[fileName] = fileError
                continue
        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = parse_data(fileName, tableName, skipRows, args, transformersTablesSchema)

        # Checking if no error was found during loading CSV from OS
        if df is not False:

            if args.consolidate_dataframes:

                try:
                    df_concat = pd.concat(
                        [dataframes[str(tableName).upper()], df], axis=0
                    )
                    # Trimming the data before storing it
                    dataframes[str(tableName).upper()] = trim_dataframe(df_concat)
                    print(
                        " Concatenated into an existing dataframe for table name {}".format(
                            tableName
                        )
                    )

                except Exception:
                    # Trimming the data before storing it
                    dataframes[str(tableName).upper()] = trim_dataframe(df)

            else:
                # Trimming the data before storing it
                dataframes[str(tableName).upper()] = trim_dataframe(df)

            transformersTablesSchema = detect_schema(
                args.schema_detection,
                transformersTablesSchema,
                transformersParameters,
                tableName,
                df,
            )

    return dataframes, transformersTablesSchema


def detect_schema(
    schema_detection: str,
    transformersTablesSchema,
    transformersParameters,
    tableName,
    df,
):

    if schema_detection.upper() == "AUTO":
        # In the arguments if we want to use AUTO schema detection

        # Replaces whatever is in there
        transformersTablesSchema[tableName] = add_bq_data_type(
            list(df.columns), "STRING"
        )

    elif schema_detection.upper() == "FILLGAP":
        # In the arguments if we want to try to only use it when the configuration file do not have it already

        if transformersTablesSchema.get(str(tableName).lower()) is None:

            # Adds configuration whenever this is not present
            transformersTablesSchema[str(tableName).lower()] = add_bq_data_type(
                list(df.columns), "STRING"
            )
            print(
                "INFO: Optimus Prime is filling the gap in the transformers.json schema definition for {} table.\n".format(
                    tableName
                )
            )

    return transformersTablesSchema


def validate_csv(file_name: str, table_header, args):
    fileerror = None
    try:
        df = pd.read_csv(
            file_name,
            sep=str(args.sep),
            skiprows=2,
            na_values="n/a",
            keep_default_na=True,
            skipinitialspace=True,
            nrows=10,
            names=table_header,
            index_col=False,
        )
        if df.empty:
            ## If file has header but no rows
            fileerror = "File seems to be Empty"
        else:
            with open(file_name, "r") as f:
                lines = f.readlines()
                last_line = lines[-1]
                # if 'ORA-' in f.read():
                if any(line.startswith("ORA-") for line in lines):
                    fileerror = "File has ORA-Errors"
                if last_line.startswith("Elapsed:"):
                    fileerror = "File has Elapsed time message from Oracle, Please remove the message and reprocess"
    except pd.errors.EmptyDataError:
        ## If file has no records
        fileerror = "File seems to be Empty"
    except UnicodeDecodeError:
        fileerror = "File seems to be of improper format"
    except Exception as otherErr:
        fileerror = "File has Errors - {}".format(otherErr)

    return fileerror


def add_bq_data_type(column_list, data_type):

    newColumnList = []

    # Cleaning header
    column_list = clean_csv_headers(column_list)
    column_list = str(column_list).split(",")

    for column in column_list:
        newColumnList.append([column, data_type])

    return newColumnList


def clean_csv_headers(header_string: str):

    header_string = (
        str(header_string)
        .replace("'||", "")
        .replace("||'", "")
        .replace("'", "")
        .replace('"', "")
        .replace("[", "")
        .replace("]", "")
        .replace(" ", "")
        .strip()
    )

    return header_string


def trim_dataframe(df):
    """Removing spaces (TRIM/Strip) for ALL columns"""
    df.columns = df.columns.str.replace(" ", "")
    cols = list(df.columns)
    # df[cols] = df[cols].apply(lambda x: x.str.strip())
    # df = df.applymap(lambda x: x.strip() if isinstance(x, str) else x)

    for column in cols:
        try:
            df[column] = df[column].astype(str).str.strip()
        except Exception:
            pass

    # trimmed dataframe
    return df


def getAllReShapedDataframes(
    dataframes,
    transformersTablesSchema,
    transformersParameters,
    transformerRulesConfig,
    args,
    collectionKey,
    fileList,
):
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataframes is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataframes

    if transformersParameters.get("op_enable_reshape_for") is not None:
        # if the parameter is set to any value

        executedRulesList = []

        for tableName_RuleID in transformersParameters.get(
            "op_enable_reshape_for"
        ).split(","):
            # This parameter accepted multiple values

            tableName = str(tableName_RuleID).split(":")[0]
            ruleID = str(tableName_RuleID).split(":")[1]
            resCSVCreation = False

            (
                transformerParameterResults,
                transformersResults,
                fileList,
                dataframes,
            ) = run_rules(
                "0",
                transformerRulesConfig,
                dataframes,
                ruleID,
                args,
                None,
                transformersTablesSchema,
                fileList,
                executedRulesList,
                transformersParameters,
                None,
                None,
            )
            print(
                "Reshaping Rule Processed: {} for the table name {}".format(
                    ruleID, tableName
                )
            )

            # Including rules already executed to be avoided
            executedRulesList.append(ruleID)

            if dataframes.get(str(tableName)) is not None:

                if transformerParameterResults[ruleID]["Status"] == "EXECUTED":

                    if transformersResults.get(str(tableName)) is not None:

                        reshapedTableName = str(tableName).lower() + "_rs"

                        try:
                            df = getReShapedDataframe(
                                dataframes[str(tableName)],
                                transformersResults[str(tableName)],
                            )
                            dataframes[reshapedTableName.upper()] = df
                        except Exception as e:
                            df = None
                            logger.warning(
                                "WARNING: Optimus Prime could not ReShape the table %s due to a fatal error.",
                                tableName,
                            )
                            logger.exception(e)
                        # collectionKey already contains .csv
                        fileName = (
                            str(getattr(args, "files_location"))
                            + "/opdbt__"
                            + reshapedTableName
                            + "__"
                            + str(collectionKey)
                        )

                        if df is not None:
                            # Writes CSVs from Dataframes when parameter store in CSV_ONLY or BIGQUERY
                            (
                                resCSVCreation,
                                transformersTablesSchema,
                            ) = createCSVFromDataframe(
                                dataframes[reshapedTableName.upper()],
                                transformersResults[str(tableName)],
                                args,
                                fileName,
                                transformersTablesSchema,
                                str(reshapedTableName).lower(),
                                True,
                            )

                        if resCSVCreation:
                            # If CSV creation was successfully then we will add this to the list of files to be imported

                            fileList.append(fileName)

                    # For cases in which we are trying to reshape a variable that does not exist
                    else:

                        print(
                            "\nThere is no parameter set to define the reshape process for: {}".format(
                                str(tableName)
                            )
                        )
                        print(
                            "This is all valid reshape configurations found: {}\n".format(
                                str(transformersParameters.keys())
                            )
                        )

                # For rules that were not executed sucessfully
                else:

                    if transformerParameterResults[ruleID]["Status"] == "SKIPPED":

                        print("The rule {} was SKIPPED due to transfomers.json")

                    elif transformerParameterResults[ruleID]["Status"] == "FAILED":

                        print("The rule {} FAILED during execution")

            # For cases in which we are trying to reshape a CSV/tablename that does not exist
            else:

                print(
                    "\nWARNING: There is no data parsed from CSVs named {}".format(
                        str(tableName)
                    )
                )
                print(
                    "WARNING: This is all valid CSVs names {}\n".format(
                        str(dataFrames.keys())
                    )
                )

    return dataframes, fileList, transformersTablesSchema, executedRulesList


def createCSVFromDataframe(
    df,
    transformersParameters,
    args,
    fileName,
    transformersTablesSchema,
    tableName,
    fixDataframeColumns,
):

    if transformersParameters["store"] in ("CSV_ONLY", "BIGQUERY"):

        # STEP: Creating 1 row empty in the file

        # Make sure file will have same format (skipping first line as others) as the ones coming from oracle_db_assessment.sql
        df1 = pd.DataFrame({"a": [np.nan] * 1})
        df1.to_csv(fileName, sep=str(args.sep), index=False, header=None)

        # STEP: Transform a multi-index/column (hierarchical columns) into regular columns
        if fixDataframeColumns:
            multiIndexColumns = df.columns
            df.columns = getNewNamesFromMultiColumns(
                transformersParameters["from_to_rows_to_columns"],
                multiIndexColumns,
                True,
            )
            df.reset_index(drop=True, inplace=True)

        # Always AUTO because we never know the column order in which the dataframe will be
        transformersTablesSchema = detect_schema(
            "AUTO",
            transformersTablesSchema,
            transformersParameters,
            str(tableName).lower(),
            df,
        )

        # STEP: Writing dataframe to CSV in append mode

        df.to_csv(fileName, sep=str(args.sep), header=True, index=False, mode="a")
        # df.to_hdf(fileName, key='optimus')

        print(
            '\n Sucessfully created filename "{}" for table name "{}".\n'.format(
                fileName, tableName
            )
        )

        return True, transformersTablesSchema

    return False, transformersTablesSchema


def getReShapedDataframe(df, transformersParameters):
    # Function to get a dataframe in one format and reshape it to another one that would make a lot simpler to create rules on.
    # Input dataframe to be reshaped example:
    #
    # FROM:
    #   DBID	HOUR	METRIC	PERC50	PERC90	PERC95
    #   1	0	Active Sessions	15	20	22
    #   1	1	Active Sessions	14	18	19
    #   1	2	Active Sessions	13	18	18
    #   1	0	User Transaction Per Sec	369	450	460
    #   1  	1	User Transaction Per Sec	301	400	420
    #   1	2	User Transaction Per Sec	280	390	400
    #   1	0	Physical Reads	904	1405	1500
    #   1	1	Physical Reads	1050	1589	1600
    #   1	2	Physical Reads	1120	1400	1450
    #
    # TO: (Using a from/to: Active Sessions == AAS, User Transaction Per Sec == UT)
    #   DBID	HOUR	AAS_PERC90  UT_PERC90   AAS_PERC95    UT_PER95
    #   1	0	20	22	450	460
    #   1	1	18	19	400	420
    #   1	2	18	18	390	400

    if df.empty:
        return df

    # Columns that will remain in a row format as indexes
    frozenIndex = []
    frozenIndex = transformersParameters["INDEX_COLUMNS"]

    # Column in which its content will be pivoted to columns
    # For example: TARGET_COLUMN = 'IOPS'
    targetColumn = ""
    targetColumn = transformersParameters["TARGET_COLUMN"]

    # Values refered to the TARGET_COLUMN that will be shown (as second level column)
    # For example: TARGET_COLUMN = 'IOPS' & TARGET_STATS_COLUMNS = 'AVG' THEN it means that we will get AVG IOPs
    targetStatsColumn = []
    targetStatsColumn = transformersParameters["TARGET_STATS_COLUMNS"]

    # Check if dataframe needs to be filtered
    if str(transformersParameters["filterrows"]).upper() == "YES":

        # Using the keys from the dictionary which are the affected rows to be pivoted to columns as filters
        filterLIst = transformersParameters["from_to_rows_to_columns"].keys()
        booleanFilteredSeries = df[targetColumn].isin(filterLIst)
        df = df[booleanFilteredSeries]

        if df.empty:
            print(
                "\nWARNING: After filtering the dataframe using: \n {} \n The dataframe became empty. Check parameter from_to_rows_to_columns from transformers.json.".format(
                    str(transformersParameters["from_to_rows_to_columns"].keys())
                )
            )

    # Pivoting daframe following the parameters given
    pivoted_df = df.pivot(
        index=frozenIndex, columns=targetColumn, values=targetStatsColumn
    )

    # Getting Columns names and levels to change it
    multiIndexColumns = pivoted_df.columns

    # Function to change dataframe column names accordingly with the parameters in transformersParameters['from_to_rows_to_columns']
    multiIndexColumns = getNewNamesFromMultiColumns(
        transformersParameters["from_to_rows_to_columns"], multiIndexColumns, False
    )

    # Changing columns and its levels
    pivoted_df.columns = multiIndexColumns

    # Resetting MultiIndex Frozen
    pivoted_df.reset_index(inplace=True)

    return pivoted_df


def getNewNamesFromMultiColumns(newNamesMapping, multiIndex, convertColumns):
    # Function to change the column names for a multi index / hirerarrical columns dataframe based on a hash table with from/to names
    # Example of multiIndex:
    # MultiIndex([('PERC90',                       'Average Active Sessions'),
    #            ('PERC90', 'Average Synchronous Single-Block Read Latency'),
    #            ('PERC90',                  'Background CPU Usage Per Sec'),
    #            ('PERC90',                             'CPU Usage Per Sec'),
    #            ('PERC90',                      'DB Block Changes Per Txn'),
    #            ('PERC90',                      'Enqueue Requests Per Txn'),],
    #           )
    # If convertColumns == TRUE we are writing to CSV else we are manopulating a dataframe

    # Turning a tuple into a list in order to be changed
    multiIndex = list(multiIndex)

    # Converted list from hirerarrical columns
    normalizedColumnsList = []

    # Variable to be used in the return accordingly with parameter convertColumns
    resultColumns = None

    for index in range(len(multiIndex)):

        if newNamesMapping.get(multiIndex[index][1]) is not None:
            # If the column name in the database (coming from multiIndex) exists in the hash table, then it means we need to change current column name.

            # Turning a tuple into a list in order to be changed
            tempList = list(multiIndex[index])

            # Getting new column name
            tempList[1] = newNamesMapping.get(multiIndex[index][1])

            # After the change tuning it back into a tuple
            multiIndex[index] = tuple(tempList)

            # Creates the normalized dataframe column names. Using new column name
            normalizedColumnsList.append(
                str(tempList[1]) + "_" + str(multiIndex[index][0])
            )

        else:
            # Nothing to do related to changing the column names and we use the current dataframe column names to create a non hirerarrical columns

            # if str(multiIndex[index][1]) != '':
            # str(multiIndex[index][1]) == '' then the column used to be index for the dataframe and therefore not part of the hirerarrical columns structure

            # Creates the normalized dataframe column names. For columns that are hirerarrical
            normalizedColumnsList.append(
                str(multiIndex[index][1]) + "_" + str(multiIndex[index][0])
            )
            # else:
            # Creates the normalized dataframe column names. For columns that are NON hirerarrical (Used to be dataframe index)
            # normalizedColumnsList.append(str(multiIndex[index][0]))

    # Processing conversion of columns
    if convertColumns:
        # If convering from hirerarrical columns to non hirerarrical

        resultColumns = normalizedColumnsList

    else:
        # if keeping it hirerarrical columns

        # Retuning a tuple again
        resultColumns = tuple(multiIndex)

    # To be used as dataframe columns. I.E: newdf.columns = resultColumns
    return resultColumns
