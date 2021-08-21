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


import pandas as pd
import numpy as np


import json

import import_db_assessment

def createTransformersVariable(transformerRule):
# Convert the JSON fields into variables like dictionaries, lists, string and numbers and return it

    if str(transformerRule['action_details']['datatype']).upper() == 'DICTIONARY':
    # For dictionaries

        return json.loads(str(transformerRule['action_details']['value']).strip())

    elif str(transformerRule['action_details']['datatype']).upper() == 'LIST':
    # For Lists it is expected to be separated by comma

        return str(transformerRule['action_details']['value']).split(',')

    elif str(transformerRule['action_details']['datatype']).upper() == 'STRING':
    # For strings we just need to carry out the content

        return str(transformerRule['action_details']['value'])

    elif str(transformerRule['action_details']['datatype']).upper() == 'NUMBER':
    # For number we are casting it to float

        return float(transformerRule['action_details']['value'])

    else:
    # If the JSON file has any value not expected

        return None

def runRules(transformerRules, dataFrames, singleRule, args, collectionKey, transformersTablesSchema, fileList, rulesAlreadyExecuted, transformersParameters):

    # Variable to keep track of rules executed and its results and status
    transformerResults = {}
    # Variable to keep track and make available all the variables from the JSON file
    transformersRulesVariables = {}

    # Standardize Statuses
    # Executed
    EXECUTEDSTATUS = 'EXECUTED'
    FAILEDSTATUS = 'FAILED'

    if singleRule:
    # If parameter is set then we will run only 1 rule
        sorted_keys = []
        sorted_keys.append(singleRule)
    else:
        # Getting ordered list of keys by priority to iterate over the dictionary
        sorted_keys = sorted(transformerRules, key=lambda x: (transformerRules[x]['priority']))

    # Looping on ALL rules from transformers.json
    for ruleItem in sorted_keys:

        stringExpression = getParsedRuleExpr(transformerRules[ruleItem]['expr1'])
        iferrorExpression = getParsedRuleExpr(transformerRules[ruleItem]['iferror'])

        if str(transformerRules[ruleItem]['status']).upper() == "ENABLED":

            if ruleItem not in rulesAlreadyExecuted:

                print('Processing rule item: "{}"\nPriority: "{}"'.format(ruleItem,transformerRules[ruleItem]['priority']))

                if str(transformerRules[ruleItem]['type']).upper() == "VARIABLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATE":
                # transformers.json asking to create a variable which is a dictionary

                    try:
                        transformerResults[ruleItem] = {'Status': EXECUTEDSTATUS, 'Result Value': createTransformersVariable(transformerRules[ruleItem])}
                        transformersRulesVariables[transformerRules[ruleItem]['action_details']['varname']] = transformerResults[ruleItem]['Result Value']

                    except:
                        # In case of any issue the rule will be marked as FAILEDSTATUS
                        transformerResults[ruleItem] = {'Status': FAILEDSTATUS, 'Result Value': None}
                        transformersRulesVariables[transformerRules[ruleItem]['action_details']['varname']] = None

                elif str(transformerRules[ruleItem]['type']).upper() in ("NUMBER","FREESTYLE") and str(transformerRules[ruleItem]['action']).upper() == "ADD_OR_UPDATE_COLUMN":
                # transformers.json asking to add a column that is type number meaning it can be a calculation and the column to be added is NUMBER too

                    # Where the result of expr1 will be saved initially
                    dfTargetName = transformerRules[ruleItem]['action_details']['dataframe_name']
                    columnTargetName = transformerRules[ruleItem]['action_details']['column_name']
                    ruleCondition = True

                    try:
                        ruleConditionString = str(transformerRules[ruleItem]['ifcondition1'])
                    except KeyError:
                        ruleConditionString = None

                    # In case ifcondition1 (transformers.json) is set for the rule
                    if ruleConditionString is not None and ruleConditionString != "":

                        try:
                            ruleCondition = eval (ruleConditionString)
                            print ('ruleCondition = {}'.format(ruleCondition))
                        except:
                            print ('\n Error processing ifcondition1 "{}" for rule "{}". So, this rule will be skipped.\n'.format(ruleConditionString,ruleItem))
                            continue
                    
                    if not ruleCondition:
                        print ('WARNING: This rule "{}" will be skipped because of "ifcondition1" from transformers.json is FALSE.'.format(ruleItem))
                        continue


                    try:
                        dataFrames[str(dfTargetName).upper()][str(columnTargetName).upper()] = execStringExpression(stringExpression,iferrorExpression, dataFrames)
                        df = dataFrames[str(dfTargetName).upper()]
                    except KeyError:
                        print ('\n WARNING: The rule "{}" could not be executed because the variable "{}" used in the transformers.json could not be found.\n'.format(ruleItem, str(dfTargetName).upper()))
                        continue

                    newTableName = str(transformerRules[ruleItem]['action_details']['target_dataframe_name']).lower()
                    fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + newTableName + '__' + collectionKey

                    resCSVCreation, transformersTablesSchema = createCSVFromDataframe(df, transformerRules[ruleItem]['action_details'], args, fileName, transformersTablesSchema, newTableName, False)

                    # Creating the new dataframe
                    dataFrames[str(newTableName).upper()] = df

                    if resCSVCreation:
                    # If CSV creation was successfully then we will add this to the list of files to be imported
                        fileList.append(fileName)

                elif str(transformerRules[ruleItem]['type']).upper() == "FREESTYLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATE_OR_REPLACE_DATAFRAME":
                # 

                    df = execStringExpression(stringExpression,iferrorExpression,dataFrames)

                    if df is None:
                        print('\n WARNING: The rule "{}" could not be executed because the expression "{}" used in the transformers.json could not be executed.\n'.format(ruleItem,stringExpression))
                        continue

                    newTableName = str(transformerRules[ruleItem]['action_details']['dataframe_name']).lower()
                    fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + newTableName + '__' + collectionKey

                    resCSVCreation, transformersTablesSchema = createCSVFromDataframe(df, transformerRules[ruleItem]['action_details'], args, fileName, transformersTablesSchema, newTableName, False)

                    # Creating the new dataframe
                    dataFrames[str(transformerRules[ruleItem]['action_details']['dataframe_name']).upper()] = df

                    if resCSVCreation:
                    # If CSV creation was successfully then we will add this to the list of files to be imported
                        fileList.append(fileName)

                elif str(transformerRules[ruleItem]['type']).upper() == "FREESTYLE" and str(transformerRules[ruleItem]['action']).upper() == "FREESTYLE":

                    try:
                        eval (stringExpression)
                    except KeyError:
                        print ('\n WARNING: The rule "{}" could not be executed because the expr1 "{}" used in the transformers.json could not be executed.\n'.format(ruleItem, stringExpression))
                        continue

                    newTableName = str(transformerRules[ruleItem]['action_details']['target_dataframe_name']).lower()
                    fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + newTableName + '__' + collectionKey

                    resCSVCreation, transformersTablesSchema = createCSVFromDataframe(df, transformerRules[ruleItem]['action_details'], args, fileName, transformersTablesSchema, newTableName, False)

                    # Creating the new dataframe
                    dataFrames[str(newTableName).upper()] = df

                    if resCSVCreation:
                    # If CSV creation was successfully then we will add this to the list of files to be imported
                        fileList.append(fileName)

    return transformerResults, transformersRulesVariables, fileList, dataFrames

def execStringExpression(stringExpression,iferrorExpression, dataFrames):

    try:
        res = eval (stringExpression)
    except:
        try:
            res = eval (iferrorExpression)
        except:
            res = None


    return res

def getParsedRuleExpr(ruleExpr):
# Function to get a clean string to be executed in eval function. The input is a string with many components separated by ; coming from transformers.json

    ruleComponents = []
    ruleComponents = str(ruleExpr).split(';')

    finalExpression = ''

    for ruleItem in ruleComponents:

        ruleItem = ruleItem.strip()

        finalExpression = str(finalExpression) + str(ruleItem) + ' '


    return finalExpression


def getRulesFromJSON(jsonFileName):
# Read JSON file from the OS and turn it into a hash table

    with open(jsonFileName) as f:
        transformerRules = json.load(f)

    return transformerRules

def getDataFrameFromCSV(csvFileName,tableName,skipRows,separatorString,transformersTablesSchema):
# Read CSV files from OS and turn it into a dataframe

    paramCleanDFHeaders = False
    paramGetHeadersFromConfig = True

    try:
        
        if paramGetHeadersFromConfig:
            
            if transformersTablesSchema.get(tableName):
                
                try:

                    tableHeaders = getDFHeadersFromTransformers(tableName,transformersTablesSchema)
                    tableHeaders = [header.upper() for header in tableHeaders]
                    df = pd.read_csv(csvFileName, skiprows=skipRows+1, header=None, names=tableHeaders)

                except Exception as dataframeHeaderErr:
                    
                    print ('\nThe filename {} for the table {} could not be imported using the column names {}.\n'.format(csvFileName,tableName,tableHeaders))
                    paramCleanDFHeaders = True
                    df = pd.read_csv(csvFileName, skiprows=skipRows)

            else:
            
                df = pd.read_csv(csvFileName, skiprows=skipRows)

        # In case we need to clean some headers from dataframe
        if paramCleanDFHeaders:
            columList = df.columns.values.tolist()
            columList = cleanCSVHeaders(columList)
            columList = str(columList).strip().split(',')
            columList = [column.strip() for column in columList]
            df.columns = columList

    except Exception as generalErr:
        print ('\nThe filename {} is most likely empty.\n'.format(csvFileName))
        return False

    return df

def getDFHeadersFromTransformers(tableName,transformersTablesSchema):

    tableConfig = transformersTablesSchema.get(tableName)

    tableHeaders = [header[0] for header in tableConfig]

    return tableHeaders
    
def getAllDataFrames(fileList, skipRows, collectionKey, args, transformersTablesSchema, dbAssessmentDataframes, transformersParameters):
# Fuction to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.
# This function returns a dictionary with dataframes from CSVs

    separatorString = args.sep

    # Hash table to store dataframes after being loaded from CSVs
    dataFrames = dbAssessmentDataframes

    fileList.sort()

    for fileName in fileList:

        # Verifying if the file is a file that came from the SQL Script or is this is a result of a previous execution from transformers.json in which a file had been saved. I.E: Reshaped Dataframes
        collectionType = import_db_assessment.getObjNameFromFiles(str(fileName),'__',0)
        collectionType = collectionType.split('/')[-1]

        if collectionType == 'opdbt':
        # This file is not from SQL Script. Meaning this is a file generated by Optimus Prime in a prior execution. Skipping CSV files that are result of a previous transformation execution
            
            continue

        # Final table name from the CSV file names
        tableName = import_db_assessment.getObjNameFromFiles(fileName,'__',1)

        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = getDataFrameFromCSV(fileName,tableName,skipRows,separatorString,transformersTablesSchema)
        
        # Checking if no error was found during loading CSV from OS
        if df is not False:
            # Trimming the data before storing it
            dataFrames[str(tableName).upper()] = trimDataframe(df)
            
            transformersTablesSchema = processSchemaDetection(args.schemadetection,transformersTablesSchema, transformersParameters, tableName, df)

    return dataFrames, transformersTablesSchema

def processSchemaDetection(schemadetection,transformersTablesSchema, transformersParameters, tableName, df):

    if str(schemadetection).upper() == 'AUTO':
    # In the arguments if we want to use AUTO schema detection

        # Replaces whatever is in there
        transformersTablesSchema[tableName] = addBQDataType(list(df.columns), 'STRING')
        
    elif str(schemadetection).upper() == 'FILLGAP':
    # In the arguments if we want to try to only use it when the configuration file do not have it already

        if transformersTablesSchema.get(str(tableName).lower()) is None:

            # Adds configuration whenever this is not present
            transformersTablesSchema[str(tableName).lower()] = addBQDataType(list(df.columns), 'STRING')
            print('WARNING: Optimus Prime is filling the gap in the transformers.json schema definition for {} table.\n'.format(tableName))
    
    return transformersTablesSchema

def addBQDataType(columList, dataType):

    newColumnList = []

    # Cleaning header
    columList = cleanCSVHeaders(columList)
    columList = str(columList).split(',')

    for column in columList:
        newColumnList.append([column,dataType])
    
    return newColumnList

def cleanCSVHeaders(headerString):

    headerString = str(headerString).replace("'||","").replace("||'","").replace("'","").replace('"','').replace("[","").replace("]","").replace(" ","").strip()

    return headerString

def trimDataframe(df):

    # Removing spaces (TRIM/Strip) for ALL columns
    df.columns = df.columns.str.replace(' ', '')
    cols = list(df.columns)
    #df[cols] = df[cols].apply(lambda x: x.str.strip())
    #df = df.applymap(lambda x: x.strip() if isinstance(x, str) else x)

    for column in cols:
        try:
            df[column] = df[column].str.strip()
        except:
            None

    # trimmed dataframe
    return df

def rewriteTrimmedCSVData(dataFrames, transformersParameters, transformersTablesSchema, fileList):
# To be Deleted

    if transformersParameters.get('op_trim_csv_data') is not None:

        for csvTableData in list(transformersParameters['op_trim_csv_data']):

            if dataFrames.get(str(csvTableData).upper()) is not None:

                df = dataFrames[str(csvTableData).upper()]

                df = trimDataframe(df)

                # collectionKey already contains .log
                fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + reshapedTableName + '__' + str(collectionKey)

                # Writes CSVs from Dataframes when parameter store in CSV_ONLY or BIGQUERY
                resCSVCreation, transformersTablesSchema = createCSVFromDataframe(df, transformersResults[str(tableName)], args, fileName, transformersTablesSchema, str(reshapedTableName).lower(), True)
                
                if resCSVCreation:
                # If CSV creation was successfully then we will add this to the list of files to be imported

                    fileList.append(fileName)

def getAllReShapedDataframes(dataFrames, transformersTablesSchema, transformersParameters, transformerRulesConfig, args, collectionKey, fileList):
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataFrames is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataFrames

    if transformersParameters.get('op_enable_reshape_for') is not None:
    # if the parameter is set to any value

        executedRulesList = []

        for tableName_RuleID in transformersParameters.get('op_enable_reshape_for').split(','):
        # This parameter accepted multiple values

            tableName = str(tableName_RuleID).split(':')[0]
            ruleID = str(tableName_RuleID).split(':')[1]
            resCSVCreation = False
            
            transformerParameterResults, transformersResults, fileList, dataFrames = runRules(transformerRulesConfig, dataFrames, ruleID, args, None, transformersTablesSchema, fileList, executedRulesList, transformersParameters)
            print('Reshaping Rule Executed: {} for the table name {}'.format(ruleID,tableName))

            # Including runes already executed to be avoided
            executedRulesList.append(ruleID)

            if dataFrames.get(str(tableName)) is not None:

                if transformersResults.get(str(tableName)) is not None:

                    reshapedTableName = str(tableName).lower() + '_rs'

                    try:
                        df = getReShapedDataframe(dataFrames[str(tableName)], transformersResults[str(tableName)])
                        dataFrames[reshapedTableName.upper()] = df
                    except:
                        df = None
                        print('WARNING: Optimus Prime could not ReShape the table {} due to a fatal error.\n'.format(tableName))

                    

                    # collectionKey already contains .log
                    fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + reshapedTableName + '__' + str(collectionKey)

                    if df is not None:
                        # Writes CSVs from Dataframes when parameter store in CSV_ONLY or BIGQUERY
                        resCSVCreation, transformersTablesSchema = createCSVFromDataframe(dataFrames[reshapedTableName.upper()], transformersResults[str(tableName)], args, fileName, transformersTablesSchema, str(reshapedTableName).lower(), True)
                    
                    if resCSVCreation:
                    # If CSV creation was successfully then we will add this to the list of files to be imported

                        fileList.append(fileName)

                else:

                    print ('\nThere is not parameter set to define the reshape process for: {}'.format(str(tableName)))
                    print ('This is all valid reshape configurations found: {}\n'.format(str(transformersParameters.keys())))

            else:

                print ('\nWARNING: There is no data parsed from CSVs named {}'.format(str(tableName)))
                print ('WARNING: This is all valid CSVs names {}\n'.format(str(dataFrames.keys())))

    return dataFrames, fileList, transformersTablesSchema, executedRulesList

def createCSVFromDataframe(df, transformersParameters, args, fileName, transformersTablesSchema, tableName, fixDataframeColumns):

    if transformersParameters['store'] in ('CSV_ONLY', 'BIGQUERY'):

        #STEP: Creating 1 row empty in the file

        # Make sure file will have same format (skipping first line as others) as the ones coming from oracle_db_assessment.sql
        df1 = pd.DataFrame({'a':[np.nan] * 1})
        df1.to_csv(fileName, index=False, header=None)

        #STEP: Transform a multi-index/column (hierarchical columns) into regular columns
        if fixDataframeColumns:
            multiIndexColumns = df.columns
            df.columns = getNewNamesFromMultiColumns(transformersParameters['from_to_rows_to_columns'], multiIndexColumns, True)
            df.reset_index(drop=True, inplace=True)

        # Always AUTO because we never know the column order in which the dataframe will be
        transformersTablesSchema = processSchemaDetection('AUTO',transformersTablesSchema, transformersParameters, str(tableName).lower(), df)

        # STEP: Writing dataframe to CSV in append mode

        df.to_csv(fileName, header=True, index=False, mode='a')
        #df.to_hdf(fileName, key='optimus')

        print('\n Sucessfully created filename "{}" for table name "{}".\n'.format(fileName,tableName))

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
    frozenIndex = transformersParameters['INDEX_COLUMNS']

    # Column in which its content will be pivoted to columns
    # For example: TARGET_COLUMN = 'IOPS'
    targetColumn = ''
    targetColumn = transformersParameters['TARGET_COLUMN']

    # Values refered to the TARGET_COLUMN that will be shown (as second level column)
    # For example: TARGET_COLUMN = 'IOPS' & TARGET_STATS_COLUMNS = 'AVG' THEN it means that we will get AVG IOPs
    targetStatsColumn = []
    targetStatsColumn = transformersParameters['TARGET_STATS_COLUMNS']

    # Check if dataframe needs to be filtered
    if str(transformersParameters['filterrows']).upper() == "YES":

        # Using the keys from the dictionary which are the affected rows to be pivoted to columns as filters
        filterLIst = transformersParameters['from_to_rows_to_columns'].keys()
        booleanFilteredSeries = df[targetColumn].isin(filterLIst)
        df = df[booleanFilteredSeries]

        if df.empty:
            print('\nWARNING: After filtering the dataframe using: \n {} \n The dataframe became empty. Check parameter from_to_rows_to_columns from transformers.json.'.format(str(transformersParameters['from_to_rows_to_columns'].keys())))
        

    # Pivoting daframe following the parameters given
    pivoted_df = df.pivot(index=frozenIndex, columns=targetColumn, values=targetStatsColumn)

    # Getting Columns names and levels to change it
    multiIndexColumns = pivoted_df.columns

    # Function to change dataframe column names accordingly with the parameters in transformersParameters['from_to_rows_to_columns']
    multiIndexColumns = getNewNamesFromMultiColumns(transformersParameters['from_to_rows_to_columns'], multiIndexColumns, False)

    # Changing columns and its levels
    pivoted_df.columns = multiIndexColumns

    # Resetting MultiIndex Frozen
    pivoted_df.reset_index(inplace=True)

    return pivoted_df

def getNewNamesFromMultiColumns(newNamesMapping, multiIndex, convertColumns):
# Function to change the column names for a multi index / hirerarrical columns dataframe based on a hash table with from/to names
# Example of multiIndex:
#MultiIndex([('PERC90',                       'Average Active Sessions'),
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
            normalizedColumnsList.append(str(tempList[1]) + '_' + str(multiIndex[index][0]))

        else:
        # Nothing to do related to changing the column names and we use the current dataframe column names to create a non hirerarrical columns

            #if str(multiIndex[index][1]) != '':
            #str(multiIndex[index][1]) == '' then the column used to be index for the dataframe and therefore not part of the hirerarrical columns structure

            # Creates the normalized dataframe column names. For columns that are hirerarrical
            normalizedColumnsList.append(str(multiIndex[index][1]) + '_' + str(multiIndex[index][0]))
            #else:
                # Creates the normalized dataframe column names. For columns that are NON hirerarrical (Used to be dataframe index)
                #normalizedColumnsList.append(str(multiIndex[index][0]))


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



