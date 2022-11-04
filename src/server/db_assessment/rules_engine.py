# type: ignore[no-untyped-def] # pylint: disable=[broad-except,eval-used,unused-arg]
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
import warnings
from pathlib import Path
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Union

import numpy as np
import pandas as pd

from db_assessment import import_db_assessment

if TYPE_CHECKING:
    from .api import AppConfig

pd.options.mode.chained_assignment = None  # suppress SettingWithCopyWarning messages
warnings.simplefilter("error", pd.errors.ParserWarning)
warnings.simplefilter(action="ignore", category=FutureWarning)

logger = logging.getLogger(__name__)


def coerce_data_type(rule: Dict[str, Any]) -> Optional[Union[Any, List[str], str, float]]:
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
    execution_group,
    transformer_rules,
    dataframes,
    single_rule,
    args: "AppConfig",
    collection_key,
    transformers_table_schema,
    file_list,
    executed_rules,
    transformers_parameters,
    project_name,
    bq_dataset,
):
    """_summary_

    Args:
        execution_group (_type_): _description_
        transformer_rules (_type_): _description_
        dataframes (_type_): _description_
        single_rule (_type_): _description_
        args (AppConfig): _description_
        collection_key (_type_): _description_
        transformers_table_schema (_type_): _description_
        file_list (_type_): _description_
        executed_rules (_type_): _description_
        transformers_parameters (_type_): _description_
        project_name (_type_): _description_
        bq_dataset (_type_): _description_

    Returns:
        _type_: _description_
    """

    # Variable to keep track of rules executed and its results and status
    transformer_results = {}
    # Variable to keep track and make available all the variables from the JSON file
    rules_vars = {}

    # Standardize Statuses
    # Executed
    EXECUTED_STATUS = "EXECUTED"  # pylint: disable=[invalid-name]
    FAILED_STATUS = "FAILED"  # pylint: disable=[invalid-name]
    SKIPPED_STATUS = "SKIPPED"  # pylint: disable=[invalid-name]

    if single_rule:
        # If parameter is set then we will run only 1 rule
        sorted_keys = []
        sorted_keys.append(single_rule)
    else:
        # Getting ordered list of keys by priority to iterate over the dictionary
        sorted_keys = sorted(transformer_rules, key=lambda x: (transformer_rules[x]["priority"]))

    # Looping on ALL rules from transformers.json
    for rule_item in sorted_keys:

        str_expression = get_rule_expression(transformer_rules[rule_item]["action_details"]["expr1"])
        if_error_expression = get_rule_expression(transformer_rules[rule_item]["action_details"]["if_error"])

        if str(transformer_rules[rule_item]["status"]).upper() == "ENABLED":

            if str(transformer_rules[rule_item]["execution_group"]).upper() == str(execution_group).upper():

                if int(str(transformers_parameters["db_version"]).replace(".", "")[:3]) in range(
                    int(str(transformer_rules[rule_item]["min_db_version"]).replace(".", "")[:3]),
                    int(str(transformer_rules[rule_item]["max_db_version"]).replace(".", "")[:3]) + 1,
                ):

                    if int(str(transformers_parameters["collection_version"]).replace(".", "")[:3]) in range(
                        int(str(transformer_rules[rule_item]["min_sql_script_version"]).replace(".", "")[:3]),
                        int(str(transformer_rules[rule_item]["max_sql_script_version"]).replace(".", "")[:3]) + 1,
                    ):

                        if rule_item not in executed_rules:

                            logger.info(
                                'Processing rule  "%s"  with priority %s',
                                rule_item,
                                transformer_rules[rule_item]["priority"],
                            )

                            if (
                                str(transformer_rules[rule_item]["action_details"]["type"]).upper() == "VARIABLE"
                                and str(transformer_rules[rule_item]["action_details"]["action"]).upper() == "CREATE"
                            ):
                                # transformers.json asking to create a variable which is a dictionary

                                try:
                                    transformer_results[rule_item] = {
                                        "Status": EXECUTED_STATUS,
                                        "Result Value": coerce_data_type(transformer_rules[rule_item]),
                                    }
                                    rules_vars[
                                        transformer_rules[rule_item]["action_details"]["varname"]
                                    ] = transformer_results[rule_item]["Result Value"]

                                except Exception:  # pylint: disable=[broad-except]
                                    # In case of any issue the rule will be marked as FAILEDSTATUS
                                    transformer_results[rule_item] = {
                                        "Status": FAILED_STATUS,
                                        "Result Value": None,
                                    }
                                    rules_vars[transformer_rules[rule_item]["action_details"]["varname"]] = None

                            elif (
                                str(transformer_rules[rule_item]["action_details"]["type"]).upper()
                                in ("NUMBER", "FREESTYLE")
                                and str(transformer_rules[rule_item]["action_details"]["action"]).upper()
                                == "ADD_OR_UPDATE_COLUMN"
                            ):
                                # transformers.json asking to add a column that is type number
                                # meaning it can be a calculation and the column to be added is NUMBER too

                                # Where the result of expr1 will be saved initially
                                df_target_name = transformer_rules[rule_item]["action_details"]["dataframe_name"]
                                column_target_name = transformer_rules[rule_item]["action_details"]["column_name"]
                                rule_condition = True

                                try:
                                    rule_condition_string = str(
                                        transformer_rules[rule_item]["action_details"]["ifcondition1"]
                                    )
                                except KeyError:
                                    rule_condition_string = None

                                # In case ifcondition1 (transformers.json) is set for the rule
                                if rule_condition_string is not None and rule_condition_string != "":

                                    try:
                                        rule_condition = eval(rule_condition_string)
                                        logger.info("ruleCondition = %s", rule_condition)
                                    except Exception:  # pylint: disable=[broad-except]
                                        logger.warning(
                                            'Error processing ifcondition1 "%s" for rule "%s". So, this rule will be skipped',  # pylint: disable=[line-too-long]
                                            rule_condition_string,
                                            rule_item,
                                        )

                                        continue

                                if not rule_condition:
                                    logger.warning(
                                        'This rule "%s" will be skipped because of "ifcondition1" from transformers.json is FALSE.',  # pylint: disable=[line-too-long]
                                        rule_item,
                                    )
                                    continue

                                try:
                                    dataframes[str(df_target_name).upper()][
                                        str(column_target_name).upper()
                                    ] = exec_string_expr(str_expression, if_error_expression, dataframes)
                                    df = dataframes[str(df_target_name).upper()].copy()
                                except KeyError:
                                    logger.warning(
                                        'The rule "%s" could not be executed because the variable "%s" used in the transformers.json could not be found.',  # pylint: disable=[line-too-long]
                                        rule_item,
                                        str(df_target_name).upper(),
                                    )
                                    continue

                                new_table_name = str(
                                    transformer_rules[rule_item]["action_details"]["target_dataframe_name"]
                                ).lower()
                                file_name = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + new_table_name
                                    + "__"
                                    + collection_key
                                )

                                (csv_created, transformers_table_schema,) = create_csv_from_dataframe(
                                    df,
                                    transformer_rules[rule_item]["action_details"],
                                    args,
                                    file_name,
                                    transformers_table_schema,
                                    new_table_name,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[str(new_table_name).upper()] = df

                                if csv_created:
                                    # If CSV creation was successfully
                                    # then we will add this to the list of files to be imported
                                    file_list.append(file_name)

                            elif (
                                str(transformer_rules[rule_item]["action_details"]["type"]).upper() == "FREESTYLE"
                                and str(transformer_rules[rule_item]["action_details"]["action"]).upper()
                                == "CREATE_OR_REPLACE_DATAFRAME"
                            ):
                                #

                                df = exec_string_expr(str_expression, if_error_expression, dataframes)

                                if df is None:
                                    logger.warning(
                                        'The rule "%s" could not be executed because the expression "%s" used in the transformers.json could not be executed.',  # pylint: disable=[line-too-long]
                                        rule_item,
                                        str_expression,
                                    )
                                    continue

                                new_table_name = str(
                                    transformer_rules[rule_item]["action_details"]["dataframe_name"]
                                ).lower()
                                file_name = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + new_table_name
                                    + "__"
                                    + collection_key
                                )

                                (csv_created, transformers_table_schema,) = create_csv_from_dataframe(
                                    df,
                                    transformer_rules[rule_item]["action_details"],
                                    args,
                                    file_name,
                                    transformers_table_schema,
                                    new_table_name,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[
                                    str(transformer_rules[rule_item]["action_details"]["dataframe_name"]).upper()
                                ] = df

                                if csv_created:
                                    # If CSV creation was successfully
                                    # then we will add this to the list of files to be imported
                                    file_list.append(file_name)

                            elif (
                                str(transformer_rules[rule_item]["action_details"]["type"]).upper() == "FREESTYLE"
                                and str(transformer_rules[rule_item]["action_details"]["action"]).upper() == "FREESTYLE"
                            ):

                                try:
                                    eval(str_expression)
                                except KeyError:
                                    logger.warning(
                                        'The rule "%s" could not be executed because the expression "%s" used in the transformers.json could not be executed.',  # pylint: disable=[line-too-long]
                                        rule_item,
                                        str_expression,
                                    )
                                    continue

                                new_table_name = str(
                                    transformer_rules[rule_item]["action_details"]["target_dataframe_name"]
                                ).lower()
                                file_name = (
                                    str(getattr(args, "files_location"))
                                    + "/opdbt__"
                                    + new_table_name
                                    + "__"
                                    + collection_key
                                )

                                (csv_created, transformers_table_schema,) = create_csv_from_dataframe(
                                    df,
                                    transformer_rules[rule_item]["action_details"],
                                    args,
                                    file_name,
                                    transformers_table_schema,
                                    new_table_name,
                                    False,
                                )

                                # Creating the new dataframe
                                dataframes[str(new_table_name).upper()] = df

                                if csv_created:
                                    # If CSV creation was successfully then add this to the list of files to be imported
                                    file_list.append(file_name)

                            elif (
                                str(transformer_rules[rule_item]["action_details"]["type"]).upper() == "CREATE VIEW"
                                and str(transformer_rules[rule_item]["action_details"]["action"]).upper()
                                == "EXECUTE_SQL"
                            ):

                                view_name = transformer_rules[rule_item]["action_details"]["target_object_name"]
                                view_sql_query = transformer_rules[rule_item]["action_details"]["expr1"]
                                view_sql_query = "".join(view_sql_query)

                                import_db_assessment.create_views(project_name, bq_dataset, view_name, view_sql_query)

                    else:
                        logger.debug(
                            'The rule "%s" is being skipped because of the Optimus Prime SQL Version is %s and not eligible for this rule based on transformers.json configuration file',  # pylint: disable=[line-too-long]
                            rule_item,
                            str(transformers_parameters["collection_version"]).replace(".", "")[:3],
                        )

                        transformer_results[rule_item] = {
                            "Status": SKIPPED_STATUS,
                            "Result Value": "Due to Optimus Prime SQL Version configuration on transformers.json",
                        }

                else:
                    logger.debug(
                        'The rule "%s" is being skipped because the Database Version is %s and not eligible for this rule based on transformers.json configuration file',  # pylint: disable=[line-too-long]
                        rule_item,
                        str(transformers_parameters["db_version"]).replace(".", "")[:3],
                    )

                    transformer_results[rule_item] = {
                        "Status": SKIPPED_STATUS,
                        "Result Value": "Due to the Database Version configuration on transformers.json",
                    }
            else:
                transformer_results[rule_item] = {
                    "Status": SKIPPED_STATUS,
                    "Result Value": "Due to the EXECUTION GROUP configuration on transformers.json",
                }

        else:
            logger.debug(
                'The rule "%s" is being skipped because it is DISABLED in transformers.json configuration file',
                rule_item,
            )

            transformer_results[rule_item] = {
                "Status": SKIPPED_STATUS,
                "Result Value": "Due to the STATUS configuration on transformers.json",
            }

    return transformer_results, rules_vars, file_list, dataframes


def exec_string_expr(str_expression, if_error_expression, dataframes):
    """_summary_

    Args:
        str_expression (_type_): _description_
        if_error_expression (_type_): _description_
        dataframes (_type_): _description_

    Returns:
        _type_: _description_
    """

    try:
        res = eval(str_expression)
    except Exception:
        try:
            res = eval(if_error_expression)
        except Exception:
            res = None

    return res


def get_rule_expression(rule_expr) -> str:
    """_summary_

    Args:
        rule_expr (_type_): _description_

    Returns:
        str: _description_
    """
    # Function to get a clean string to be executed in eval function.
    # The input is a string with many components separated by ; coming from transformers.json

    rule_components = str(rule_expr).split(";")

    final_expr = ""
    for rule_item in rule_components:
        final_expr = f"{final_expr}{rule_item.strip()} "

    return final_expr


def load_from_config(config_path: str):
    with open(config_path, encoding="UTF-8") as f:
        return json.load(f)


def parse_data(
    csv_filename: str,
    table_name: str,
    skip_rows: int,
    args: "AppConfig",
    table_schema,
):
    """Read CSV files from OS and turn it into a dataframe"""

    param_clean_df_headers = False
    param_get_headers_from_config = True

    # Configuration files always will be ,
    if "opConfig" in csv_filename:
        file_separator = ","
    else:
        file_separator = args.sep

    try:

        if param_get_headers_from_config:

            if table_schema.get(table_name):

                try:

                    table_headers = [header.upper() for header in get_headers_from_config(table_name, table_schema)]
                    df = pd.read_csv(
                        csv_filename,
                        skiprows=skip_rows + 1,
                        sep=str(file_separator),
                        header=None,
                        names=table_headers,
                        na_values="n/a",
                        keep_default_na=True,
                        skipinitialspace=True,
                    )

                except Exception:

                    logger.warning(
                        "The filename %s for the table %s could not be imported using the column names %s.",
                        csv_filename,
                        table_name,
                        table_headers,
                    )
                    param_clean_df_headers = True
                    # df = pd.read_csv(csvFileName, skiprows=skipRows, keep_default_na=False, na_filter= False)
                    df = pd.read_csv(
                        csv_filename,
                        sep=str(file_separator),
                        skiprows=skip_rows,
                        na_values="n/a",
                        keep_default_na=True,
                        skipinitialspace=True,
                    )

            else:

                # df = pd.read_csv(csvFileName, skiprows=skipRows, keep_default_na=False, na_filter= False)
                df = pd.read_csv(
                    csv_filename,
                    sep=str(file_separator),
                    skiprows=skip_rows,
                    na_values="n/a",
                    keep_default_na=True,
                    skipinitialspace=True,
                )

        # Removing index from dataframe
        df.reset_index(drop=True, inplace=True)

        # In case we need to clean some headers from dataframe
        if param_clean_df_headers:
            column_list = clean_csv_headers(df.columns.values.tolist()).split(",")
            df.columns = [column.strip() for column in column_list]

    except Exception:
        logger.warning("The filename %s is most likely empty.", csv_filename)
        return False

    return df


def get_headers_from_config(table_name, transformer_tables_schema):
    """_summary_

    Args:
        table_name (_type_): _description_
        transformer_tables_schema (_type_): _description_

    Returns:
        _type_: _description_
    """

    table_config = transformer_tables_schema.get(table_name)

    headers = [header[0] for header in table_config]

    return headers


def get_all_dataframes(
    file_list,
    skip_rows,
    collection_key,
    args: "AppConfig",
    transformers_table_schema,
    db_assessment_dataframes,
    transformer_parameters,
    invalid_files,
    skip_validations,
):
    """_summary_

    Args:
        file_list (_type_): _description_
        skip_rows (_type_): _description_
        collection_key (_type_): _description_
        args (AppConfig): _description_
        transformers_table_schema (_type_): _description_
        db_assessment_dataframes (_type_): _description_
        transformer_parameters (_type_): _description_
        invalid_files (_type_): _description_
        skip_validations (_type_): _description_

    Returns:
        _type_: _description_
    """
    # Function to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.
    # This function returns a dictionary with dataframes from CSVs

    # Hash table to store dataframes after being loaded from CSVs
    dataframes = db_assessment_dataframes

    file_list.sort()
    for file_name in file_list:

        # Verifying if the file is a file that came from the SQL Script
        # or is this is a result of a previous execution from transformers.json
        # in which a file had been saved. I.E: Reshaped Dataframes
        collection_type = import_db_assessment.get_obj_name_from_files(str(file_name), "__", 0)
        collection_type = collection_type.split("/")[-1]

        if collection_type == "opdbt":
            # This file is not from SQL Script.
            # Meaning this is a file generated by Optimus Prime in a prior execution.
            # Skipping CSV files that are result of a previous transformation execution

            continue

        # Final table name from the CSV file names
        table_name = import_db_assessment.get_obj_name_from_files(file_name, "__", 1)

        if str(table_name).lower() in transformer_parameters["do_not_import"]:

            logger.info(
                "This table name %s for filename %s is being SKIPPED due to do_not_import parameter in transformers.json configuration file",  # pylint: disable=[line-too-long]
                table_name,
                Path(file_name).stem,
            )

            continue

        logger.info("Processing %s into a dataframe %s", Path(file_name).stem, table_name)

        # Validate the CSV file
        headers = [header.upper() for header in get_headers_from_config(table_name, transformers_table_schema)]
        if not skip_validations:
            file_error = validate_csv(file_name, headers, args)
            if file_error is not None:
                logger.info("File %s is skipped because of error -> %s ", Path(file_name).stem, file_error)
                invalid_files[file_name] = file_error
                continue
        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = parse_data(file_name, table_name, skip_rows, args, transformers_table_schema)

        # Checking if no error was found during loading CSV from OS
        if df is not False:

            if args.consolidate_dataframes:

                try:
                    df_concat = pd.concat([dataframes[str(table_name).upper()], df], axis=0)
                    # Trimming the data before storing it
                    dataframes[str(table_name).upper()] = trim_dataframe(df_concat)
                    logger.info(" Concatenated into an existing dataframe for table name %s", Path(file_name).stem)

                except Exception:
                    # Trimming the data before storing it
                    dataframes[str(table_name).upper()] = trim_dataframe(df)

            else:
                # Trimming the data before storing it
                dataframes[str(table_name).upper()] = trim_dataframe(df)

            transformers_table_schema = detect_schema(
                args.schema_detection,
                transformers_table_schema,
                transformer_parameters,
                table_name,
                df,
            )

    return dataframes, transformers_table_schema


def detect_schema(
    schema_detection: str,
    transformers_tables_schema,
    transformers_parameters,
    table_name,
    df,
):
    """_summary_

    Args:
        schema_detection (str): _description_
        transformers_tables_schema (_type_): _description_
        transformers_parameters (_type_): _description_
        table_name (_type_): _description_
        df (_type_): _description_

    Returns:
        _type_: _description_
    """

    if schema_detection.upper() == "AUTO":
        # In the arguments if we want to use AUTO schema detection

        # Replaces whatever is in there
        transformers_tables_schema[table_name] = add_bq_data_type(list(df.columns), "STRING")

    elif schema_detection.upper() == "FILLGAP" and transformers_tables_schema.get(str(table_name).lower()) is None:

        # Adds configuration whenever this is not present
        transformers_tables_schema[str(table_name).lower()] = add_bq_data_type(list(df.columns), "STRING")
        logger.info(
            "Optimus Prime is filling the gap in the transformers.json schema definition for %s table.", table_name
        )

    return transformers_tables_schema


def validate_csv(file_name: str, table_header, args):
    """_summary_

    Args:
        file_name (str): _description_
        table_header (_type_): _description_
        args (_type_): _description_

    Returns:
        _type_: _description_
    """
    file_error = None
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
            # If file has header but no rows
            file_error = "File seems to be Empty"
        else:
            with open(file_name, "r", encoding="utf-8") as f:
                lines = f.readlines()
                last_line = lines[-1]
                # if 'ORA-' in f.read():
                if any(line.startswith("ORA-") for line in lines):
                    file_error = "File has ORA-Errors"
                if last_line.startswith("Elapsed:"):
                    file_error = "File has Elapsed time message from Oracle, Please remove the message and reprocess"
    except pd.errors.EmptyDataError:
        # If file has no records
        file_error = "File seems to be Empty"
    except UnicodeDecodeError:
        file_error = "File seems to be of improper format"
    except Exception as e:
        file_error = f"File has Errors - {e}"

    return file_error


def add_bq_data_type(column_list, data_type):
    """_summary_

    Args:
        column_list (_type_): _description_
        data_type (_type_): _description_

    Returns:
        _type_: _description_
    """

    new_column_list = []

    # Cleaning header
    column_list = clean_csv_headers(column_list)
    column_list = str(column_list).split(",")

    for column in column_list:
        new_column_list.append([column, data_type])

    return new_column_list


def clean_csv_headers(header_string: str) -> str:
    """Clean Headers

    Args:
        header_string (str): _description_

    Returns:
        str: _description_
    """
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


def get_all_reshaped_dataframes(
    dataframes,
    table_schema,
    transformers_params,
    rules_config,
    args,
    collection_key,
    file_list,
):
    """_summary_

    Args:
        dataframes (_type_): _description_
        table_schema (_type_): _description_
        transformers_params (_type_): _description_
        rules_config (_type_): _description_
        args (_type_): _description_
        collection_key (_type_): _description_
        file_list (_type_): _description_

    Returns:
        _type_: _description_
    """
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataframes is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataframes

    if transformers_params.get("op_enable_reshape_for") is not None:
        # if the parameter is set to any value

        executed_rules_list: list[Any] = []

        for table_name_rule_id in transformers_params.get("op_enable_reshape_for").split(","):
            # This parameter accepted multiple values

            table_name = str(table_name_rule_id).split(":", maxsplit=1)[0]
            rule_id = str(table_name_rule_id).split(":")[1]
            csv_created = False

            (transformer_parameter_results, transformers_results, file_list, dataframes,) = run_rules(
                "0",
                rules_config,
                dataframes,
                rule_id,
                args,
                None,
                table_schema,
                file_list,
                executed_rules_list,
                transformers_params,
                None,
                None,
            )
            logger.info("Reshaping Rule Processed: %s for the table name %s", rule_id, table_name)

            # Including rules already executed to be avoided
            executed_rules_list.append(rule_id)

            if dataframes.get(str(table_name)) is not None:

                if transformer_parameter_results[rule_id]["Status"] == "EXECUTED":

                    if transformers_results.get(str(table_name)) is not None:

                        reshaped_table_name = str(table_name).lower() + "_rs"

                        try:
                            df = get_reshaped_dataframe(
                                dataframes[str(table_name)],
                                transformers_results[str(table_name)],
                            )
                            dataframes[reshaped_table_name.upper()] = df
                        except Exception as e:
                            df = None
                            logger.warning(
                                "WARNING: Optimus Prime could not ReShape the table %s due to a fatal error.",
                                table_name,
                            )
                            logger.exception(e)
                        # collectionKey already contains .csv
                        file_name = (
                            str(getattr(args, "files_location"))
                            + "/opdbt__"
                            + reshaped_table_name
                            + "__"
                            + str(collection_key)
                        )

                        if df is not None:
                            # Writes CSVs from Dataframes when parameter store in CSV_ONLY or BIGQUERY
                            (csv_created, table_schema,) = create_csv_from_dataframe(
                                dataframes[reshaped_table_name.upper()],
                                transformers_results[str(table_name)],
                                args,
                                file_name,
                                table_schema,
                                str(reshaped_table_name).lower(),
                                True,
                            )

                        if csv_created:
                            # If CSV creation was successfully then we will add this to the list of files to be imported

                            file_list.append(file_name)

                    # For cases in which we are trying to reshape a variable that does not exist
                    else:

                        logger.warning("There is no parameter set to define the reshape process for: %s", table_name)
                        logger.info("This is all valid reshape configurations found: %s", transformers_params.keys())

                # For rules that were not executed successfully
                else:

                    if transformer_parameter_results[rule_id]["Status"] == "SKIPPED":

                        logger.debug("The rule %s was SKIPPED due to transformers.json", rule_id)

                    elif transformer_parameter_results[rule_id]["Status"] == "FAILED":

                        logger.warning("The rule %s FAILED during execution", rule_id)

            # For cases in which we are trying to reshape a CSV/tablename that does not exist
            else:

                logger.warning("There is no data parsed from CSVs named %s", table_name)
                logger.info("This is all valid CSVs names %s", dataframes.keys())

    return dataframes, file_list, table_schema, executed_rules_list


def create_csv_from_dataframe(
    df,
    transformers_parameters,
    args,
    file_name,
    table_schema,
    table_name,
    fix_dataframe_columns,
):
    """_summary_

    Args:
        df (_type_): _description_
        transformers_parameters (_type_): _description_
        args (_type_): _description_
        file_name (_type_): _description_
        table_schema (_type_): _description_
        table_name (_type_): _description_
        fix_dataframe_columns (_type_): _description_

    Returns:
        _type_: _description_
    """

    if transformers_parameters["store"] in ("CSV_ONLY", "BIGQUERY"):

        # STEP: Creating 1 row empty in the file

        # Make sure file will have same format (skipping first line as others)
        # as the ones coming from oracle_db_assessment.sql
        df1 = pd.DataFrame({"a": [np.nan] * 1})
        df1.to_csv(file_name, sep=str(args.sep), index=False, header=None)

        # STEP: Transform a multi-index/column (hierarchical columns) into regular columns
        if fix_dataframe_columns:
            multi_index_columns = df.columns
            df.columns = get_new_names_from_multi_columns(
                transformers_parameters["from_to_rows_to_columns"],
                multi_index_columns,
                True,
            )
            df.reset_index(drop=True, inplace=True)

        # Always AUTO because we never know the column order in which the dataframe will be
        table_schema = detect_schema(
            "AUTO",
            table_schema,
            transformers_parameters,
            str(table_name).lower(),
            df,
        )

        # STEP: Writing dataframe to CSV in append mode

        df.to_csv(file_name, sep=str(args.sep), header=True, index=False, mode="a")
        # df.to_hdf(fileName, key='optimus')

        logger.debug("Modified '%s' for table name '%s'", Path(file_name).stem, table_name)

        return True, table_schema

    return False, table_schema


def get_reshaped_dataframe(df, transformer_parameters):
    """_summary_

    Args:
        df (_type_): _description_
        transformer_parameters (_type_): _description_

    Returns:
        _type_: _description_
    """
    # Function to get a dataframe in one format and reshape it to
    # another one that would make a lot simpler to create rules on.
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
    frozen_idx = transformer_parameters["INDEX_COLUMNS"]

    # Column in which its content will be pivoted to columns
    # For example: TARGET_COLUMN = 'IOPS'
    target_column = transformer_parameters["TARGET_COLUMN"]

    # Values referred to the TARGET_COLUMN that will be shown (as second level column)
    # For example: TARGET_COLUMN = 'IOPS' & TARGET_STATS_COLUMNS = 'AVG' THEN it means that we will get AVG IOPs
    target_stats_column = transformer_parameters["TARGET_STATS_COLUMNS"]

    # Check if dataframe needs to be filtered
    if str(transformer_parameters["filterrows"]).upper() == "YES":

        # Using the keys from the dictionary which are the affected rows to be pivoted to columns as filters
        filter_list = transformer_parameters["from_to_rows_to_columns"].keys()
        filtered_series = df[target_column].isin(filter_list)
        df = df[filtered_series]

        if df.empty:
            logger.warning(
                "After filtering the dataframe using: %s, The dataframe became empty. Check parameter from_to_rows_to_columns from transformers.json.",  # pylint: disable=[line-too-long]
                transformer_parameters["from_to_rows_to_columns"].keys(),
            )

    # Pivoting dataframe following the parameters given
    pivoted_df = df.pivot(index=frozen_idx, columns=target_column, values=target_stats_column)

    # Getting Columns names and levels to change it
    multi_index_columns = pivoted_df.columns

    # Function to change dataframe column names accordingly with the parameters in transformersParameters['from_to_rows_to_columns']
    multi_index_columns = get_new_names_from_multi_columns(
        transformer_parameters["from_to_rows_to_columns"], multi_index_columns, False
    )

    # Changing columns and its levels
    pivoted_df.columns = multi_index_columns

    # Resetting MultiIndex Frozen
    pivoted_df.reset_index(inplace=True)

    return pivoted_df


def get_new_names_from_multi_columns(new_names_mapping, multi_index, convert_columns):
    """_summary_

    Args:
        new_names_mapping (_type_): _description_
        multi_index (_type_): _description_
        convert_columns (_type_): _description_

    Returns:
        _type_: _description_
    """
    # Function to change the column names for a multi index /
    # hierarchical columns dataframe based on a hash table with from/to names
    # Example of multiIndex:
    # MultiIndex([('PERC90',                       'Average Active Sessions'),
    #            ('PERC90', 'Average Synchronous Single-Block Read Latency'),
    #            ('PERC90',                  'Background CPU Usage Per Sec'),
    #            ('PERC90',                             'CPU Usage Per Sec'),
    #            ('PERC90',                      'DB Block Changes Per Txn'),
    #            ('PERC90',                      'Enqueue Requests Per Txn'),],
    #           )
    # If convertColumns == TRUE we are writing to CSV else we are manipulating a dataframe

    # Turning a tuple into a list in order to be changed
    multi_index = list(multi_index)

    # Converted list from hierarchical columns
    normalized_column_list = []

    # Variable to be used in the return accordingly with parameter convertColumns
    result_columns = None

    for index in range(len(multi_index)):

        if new_names_mapping.get(multi_index[index][1]) is not None:
            # If the column name in the database (coming from multiIndex)
            # exists in the hash table, then it means we need to change current column name.

            # Turning a tuple into a list in order to be changed
            temp_list = list(multi_index[index])

            # Getting new column name
            temp_list[1] = new_names_mapping.get(multi_index[index][1])

            # After the change tuning it back into a tuple
            multi_index[index] = tuple(temp_list)

            # Creates the normalized dataframe column names. Using new column name
            normalized_column_list.append(str(temp_list[1]) + "_" + str(multi_index[index][0]))

        else:
            # Nothing to do related to changing the column names
            # and we use the current dataframe column names to create a non hierarchical columns

            # if str(multiIndex[index][1]) != '':
            # str(multiIndex[index][1]) == '' then the column used to be index
            # for the dataframe and therefore not part of the hierarchical columns structure

            # Creates the normalized dataframe column names. For columns that are hierarchical
            normalized_column_list.append(str(multi_index[index][1]) + "_" + str(multi_index[index][0]))
            # else:
            # Creates the normalized dataframe column names.
            # For columns that are NON hierarchical (Used to be dataframe index)
            # normalizedColumnsList.append(str(multiIndex[index][0]))

    # Processing conversion of columns
    if convert_columns:
        # If converting from hierarchical columns to non hierarchical

        result_columns = normalized_column_list

    else:
        # if keeping it hierarchical columns

        # Retuning a tuple again
        result_columns = tuple(multi_index)

    # To be used as dataframe columns. I.E: newdf.columns = resultColumns
    return result_columns
