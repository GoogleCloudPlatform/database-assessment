
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

def runRules(transformerRules, dataFrames, singleRule):

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

        # Promote STATUS=ENABLED to first check

        if str(transformerRules[ruleItem]['type']).upper() == "VARIABLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATE" and str(transformerRules[ruleItem]['status']).upper() == "ENABLED":
        # transformers.json asking to create a variable which is a dictionary

            try:
                transformerResults[ruleItem] = {'Status': EXECUTEDSTATUS, 'Result Value': createTransformersVariable(transformerRules[ruleItem])}
                transformersRulesVariables[transformerRules[ruleItem]['action_details']['varname']] = transformerResults[ruleItem]['Result Value']

            except:
                # In case of any issue the rule will be marked as FAILEDSTATUS
                transformerResults[ruleItem] = {'Status': FAILEDSTATUS, 'Result Value': None}
                transformersRulesVariables[transformerRules[ruleItem]['action_details']['varname']] = None

        elif str(transformerRules[ruleItem]['type']).upper() in ("NUMBER","FREESTYLE") and str(transformerRules[ruleItem]['action']).upper() == "ADD_COLUMN":
        # transformers.json asking to add a column that is type number meaning it can be a calculation and the column to be added is NUMBER too

            print ('\nProcessing NUMBER/FREESTYLE and ADD_COLUMN.\n')
            dataFrames[transformerRules[ruleItem]['action_details']['dataframe_name']][transformerRules[ruleItem]['action_details']['column_name']] = execStringExpression(stringExpression,iferrorExpression, dataFrames)

        elif str(transformerRules[ruleItem]['type']).upper() == "FREESTYLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATENEWDATAFRAME":
        # 

            print ('\nProcessing FREESTYLE and CREATENEWDATAFRAME.\n')
            dataFrames[transformerRules[ruleItem]['action_details']['dataframe_name']] = execStringExpression(stringExpression,iferrorExpression, dataFrames)



    return transformerResults, transformersRulesVariables

def execStringExpression(stringExpression,iferrorExpression, dataFrames):

    try:
        res = eval (stringExpression)
    except:
        res = eval (iferrorExpression)


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

def getDataFrameFromCSV(csvFileName,skipRows, separatorString):
# Read CSV files from OS and turn it into a dataframe

    try:
        #df = pd.read_csv(csvFileName, skiprows=skipRows, sep=separatorString, engine = 'python')
        df = pd.read_csv(csvFileName, skiprows=skipRows)
    except:
        print ('\n\n\n\nThe filename {} is empty.\n\n'.format(csvFileName))
        return False

    return df


def getAllDataFrames(fileList, skipRows, collectionKey, args, transformersTablesSchema):
# Fuction to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.
# This function returns a dictionary with dataframes from CSVs

    separatorString = args.sep

    # Hash table to store dataframes after being loaded from CSVs
    dataFrames = {}

    for fileName in fileList:

        # Verifying if the file is a file that came from the SQL Script or is this is a result of a previous execution from transformers.json in which a file had been saved. I.E: Reshaped Dataframes
        collectionType = import_db_assessment.getObjNameFromFiles(str(fileName),'__',0)
        collectionType = collectionType.split('/')[-1]

        if collectionType == 'opdbt':
        # This file is not from SQL Script. Skipping CSV files that are result of a previous transformation execution
            
            continue

        # Final table name from the CSV file names
        tableName = import_db_assessment.getObjNameFromFiles(fileName,'__',1)

        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = getDataFrameFromCSV(fileName,skipRows, separatorString)
        
        # Checking if no error was found during loading CSV from OS
        if df is not False:
            # Trimming the data before storing it
            dataFrames[str(tableName).upper()] = trimDataframe(df)
            
            transformersTablesSchema = processSchemaDetection(args.schemadetection,transformersTablesSchema, tableName, df)

    return dataFrames, transformersTablesSchema

def processSchemaDetection(schemadetection,transformersTablesSchema, tableName, df):

    if str(schemadetection).upper() == 'AUTO':
    # In the arguments if we want to use AUTO schema detection

        transformersTablesSchema[tableName] = addBQDataType(list(df.columns), 'STRING')
        
    elif str(schemadetection).upper() == 'FILLGAP':
    # In the arguments if we want to try to only use it when the configuration file do not have it already

        if transformersTablesSchema.get(str(tableName).lower()) is None:

            transformersTablesSchema[str(tableName).lower()] = addBQDataType(list(df.columns), 'STRING')
            print('WARNING: Optimus Prime is filling the gap in the transformers.json schema definition for {} table.'.format(tableName))
    
    return transformersTablesSchema

def addBQDataType(columList, dataType):

    newColumnList = []

    for column in columList:
        newColumnList.append([column,dataType])
    
    return newColumnList

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

def getAllReShapedDataframes(dataFrames, transformersTablesSchema, transformersParameters, transformerRulesConfig, args, collectionKey, fileList):
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataFrames is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataFrames

    if transformersParameters.get('op_enable_reshape_for') is not None:
    # if the parameter is set to any value

        for tableName_RuleID in transformersParameters.get('op_enable_reshape_for').split(','):
        # This parameter accepted multiple values

            tableName = str(tableName_RuleID).split(':')[0]
            ruleID = str(tableName_RuleID).split(':')[1]

            transformerParameterResults, transformersResults = runRules(transformerRulesConfig, None, ruleID)

            if dataFrames.get(str(tableName)) is not None:

                if transformersResults.get(str(tableName)) is not None:

                    df = getReShapedDataframe(dataFrames[str(tableName)], transformersResults[str(tableName)])
                    dataFrames[str(tableName) + '_RESHAPED'] = df

                    # collectionKey already contains .log
                    fileName = str(getattr(args,'fileslocation')) + '/opdbt__' + str(tableName).lower() + '_rs__' + str(collectionKey)

                    # Writes CSVs from Dataframes when parameter store in CSV_ONLY or BIGQUERY
                    resCSVCreation, transformersTablesSchema = createCSVFromDataframe(dataFrames[str(tableName) + '_RESHAPED'], transformersResults[str(tableName)], args, fileName, transformersTablesSchema, str(tableName).lower())
                    
                    if resCSVCreation:
                    # If CSV creation was successfully then we will add this to the list of files to be imported

                        fileList.append(fileName)

                else:

                    print ('\n\nThere is not parameter set to define the reshape process for: {}'.format(str(tableName)))
                    print ('This is all valid reshape configurations found: {}'.format(str(transformersParameters.keys())))

            else:

                print ('\n\nThere is no data parsed from CSVs named {}'.format(str(tableName)))
                print ('This is all valid CSVs names {}'.format(str(dataFrames.keys())))

    return dataFrames, fileList, transformersTablesSchema

def createCSVFromDataframe(df, transformersParameters, args, fileName, transformersTablesSchema, tableName):


    if transformersParameters['STORE'] in ('CSV_ONLY', 'BIGQUERY'):

        #STEP: Creating 1 row empty in the file

        # Make sure file will have same format (skipping first line as others)
        df1 = pd.DataFrame({'a':[np.nan] * 1})
        df1.to_csv(fileName, index=False, header=None)

        #STEP: Transform a multi-index/column (hierarchical columns) into regular columns

        multiIndexColumns = df.columns
        df.columns = getNewNamesFromMultiColumns(transformersParameters['FROM_TO_ROWS_TO_COLUMNS'], multiIndexColumns, True)

        df.reset_index(inplace=True)

        print(list(df.columns))

        transformersTablesSchema = processSchemaDetection('AUTO',transformersTablesSchema, str(tableName).lower() + '_rs', df)

        # STEP: Writing dataframe to CSV in append mode

        df.to_csv(fileName, header=True, index=False, mode='a')
        #df.to_hdf(fileName, key='optimus')

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
    if str(transformersParameters['FILTERROWS']).upper() == "YES":

        # Using the keys from the dictionary which are the affected rows to be pivoted to columns as filters
        filterLIst = transformersParameters['FROM_TO_ROWS_TO_COLUMNS'].keys()
        booleanFilteredSeries = df[targetColumn].isin(filterLIst)
        df = df[booleanFilteredSeries]

        if df.empty:
            print('\nWARNING: After filtering the dataframe using: \n {} \n The dataframe became empty. Check parameter FROM_TO_ROWS_TO_COLUMNS from transformers.json.'.format(str(transformersParameters['FROM_TO_ROWS_TO_COLUMNS'].keys())))
        

    # Pivoting daframe following the parameters given
    pivoted_df = df.pivot(index=frozenIndex, columns=targetColumn, values=targetStatsColumn)

    # Getting Columns names and levels to change it
    multiIndexColumns = pivoted_df.columns

    # Function to change dataframe column names accordingly with the parameters in transformersParameters['FROM_TO_ROWS_TO_COLUMNS']
    multiIndexColumns = getNewNamesFromMultiColumns(transformersParameters['FROM_TO_ROWS_TO_COLUMNS'], multiIndexColumns, False)

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


if __name__ == '__main__':

    '''

    # Getting parameters and rules from transformers.json
    transformerConfiguration = getRulesFromJSON('db-assessment/transformers.json')

    transformerRulesConfig = transformerConfiguration['rules']
    transformersParametersConfig = transformerConfiguration['parameters']

    # 
    transformerParameterResults = {}
    transformersParameters = {}
    transformerParameterResults, transformersParameters = runRules(transformersParametersConfig, None)

    fileList = import_db_assessment.getAllFilesByPattern('/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb*log')
    
    dbAssessmentDataframes = {}
    dbAssessmentDataframes = getAllDataFrames(fileList, 1)

    dbAssessmentDataframes = getAllReShapedDataframes(dbAssessmentDataframes, transformersParameters, None)

    print(dbAssessmentDataframes.keys())

    transformerParameterResults, transformersParameters = runRules(transformerRulesConfig, dbAssessmentDataframes)

'''


