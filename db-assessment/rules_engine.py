
import pandas as pd

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

def runRules(transformerRules, dataFrames):

    # Variable to keep track of rules executed and its results and status
    transformerResults = {}
    # Variable to keep track and make available all the variables from the JSON file
    transformersParameters = {}

    # Standardize Statuses
    # Executed
    EXECUTEDSTATUS = 'EXECUTED'
    FAILEDSTATUS = 'FAILED'

    # Getting ordered list of keys by priority to iterate over the dictionary
    sorted_keys = sorted(transformerRules, key=lambda x: (transformerRules[x]['priority']))


    # Looping on ALL rules from transformers.json
    for ruleItem in sorted_keys:

        stringExpression = getParsedRuleExpr(transformerRules[ruleItem]['expr1'])
        iferrorExpression = getParsedRuleExpr(transformerRules[ruleItem]['iferror'])

        if str(transformerRules[ruleItem]['type']).upper() == "VARIABLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATE" and str(transformerRules[ruleItem]['status']).upper() == "ENABLED":
        # transformers.json asking to create a variable which is a dictionary

            try:
                transformerResults[ruleItem] = {'Status': EXECUTEDSTATUS, 'Result Value': createTransformersVariable(transformerRules[ruleItem])}
                transformersParameters[transformerRules[ruleItem]['action_details']['varname']] = transformerResults[ruleItem]['Result Value']

            except:
                # In case of any issue the rule will be marked as FAILEDSTATUS
                transformerResults[ruleItem] = {'Status': FAILEDSTATUS, 'Result Value': None}
                transformersParameters[transformerRules[ruleItem]['action_details']['varname']] = None

        elif str(transformerRules[ruleItem]['type']).upper() in ("NUMBER","FREESTYLE") and str(transformerRules[ruleItem]['action']).upper() == "ADD_COLUMN":
        # transformers.json asking to add a column that is type number meaning it can be a calculation and the column to be added is NUMBER too

            print ('\nProcessing NUMBER/FREESTYLE and ADD_COLUMN.\n')
            dataFrames[transformerRules[ruleItem]['action_details']['dataframe_name']][transformerRules[ruleItem]['action_details']['column_name']] = execStringExpression(stringExpression,iferrorExpression, dataFrames)

        elif str(transformerRules[ruleItem]['type']).upper() == "FREESTYLE" and str(transformerRules[ruleItem]['action']).upper() == "CREATENEWDATAFRAME":
        # 

            print ('\nProcessing FREESTYLE and CREATENEWDATAFRAME.\n')
            dataFrames[transformerRules[ruleItem]['action_details']['dataframe_name']] = execStringExpression(stringExpression,iferrorExpression, dataFrames)


    return transformerResults, transformersParameters

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

def getDataFrameFromCSV(csvFileName,skipRows):
# Read CSV files from OS and turn it into a dataframe

    try:
        df = pd.read_csv(csvFileName, skiprows=skipRows)
    except:
        print ('\n\n\n\nThe filename {} is empty.\n\n'.format(csvFileName))
        return False

    return df


def getAllDataFrames(fileList, skipRows):
# Fuction to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.
# This function returns a dictionary with dataframes from CSVs

    # Hash table to store dataframes after being loaded from CSVs
    dataFrames = {}

    for fileName in fileList:

        # Final table name from the CSV file names
        tableName = import_db_assessment.getObjNameFromFiles(fileName,'__',1)

        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = getDataFrameFromCSV(fileName,skipRows)
        
        # Checking if no error was found during loading CSV from OS
        if df is not False:
            # Trimming the data before storing it
            dataFrames[str(tableName).upper()] = trimDataframe(df)


    return dataFrames

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

def getAllReShapedDataframes(dataFrames, transformersParameters):
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataFrames is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataFrames

    for tableName in transformersParameters['LIST_TO_RESHAPE']:

        if dataFrames.get(str(tableName)) is not None:

            if transformersParameters.get(str(tableName)) is not None:

                dataFrames[str(tableName) + '_RESHAPED'] = getReShapedDataframe(dataFrames[str(tableName)], transformersParameters[str(tableName)])
            
            else:

                print ('\n\nThere is not parameter set to define the reshape process for: {}'.format(str(tableName)))
                print ('This is all valid reshape configurations found: {}'.format(str(transformersParameters.keys())))

        else:

            print ('\n\nThere is no data parsed from CSVs named {}'.format(str(tableName)))
            print ('This is all valid CSVs names {}'.format(str(dataFrames.keys())))

    return dataFrames

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
#   DBID	HOUR	AAS_PERC90	AAS_PERC95	UT_PERC90	UT_PER95
#   1	0	20	22	450	460
#   1	1	18	19	400	420
#   1	2	18	18	390	400

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

    # Pivoting daframe following the parameters given
    pivoted_df = df.pivot(index=frozenIndex, columns=targetColumn, values=targetStatsColumn)

    # Getting Columns names and levels to change it
    multiIndexColumns = pivoted_df.columns

    # Function to change dataframe column names accordingly with the parameters in transformersParameters['FROM_TO_ROWS_TO_COLUMNS']
    multiIndexColumns = getNewNamesFromMultiColumns(transformersParameters['FROM_TO_ROWS_TO_COLUMNS'], multiIndexColumns)

    # Changing columns and its levels
    pivoted_df.columns = multiIndexColumns

    # Resetting MultiIndex Frozen
    pivoted_df.reset_index(inplace=True)

    return pivoted_df

def getNewNamesFromMultiColumns(newNamesMapping, multiIndex):

    # Turning a tuple into a list in order to be changed
    multiIndex = list(multiIndex)

    for index in range(len(multiIndex)):

        if newNamesMapping.get(multiIndex[index][1]) is not None:

            # Turning a tuple into a list in order to be changed
            tempList = list(multiIndex[index])
            tempList[1] = newNamesMapping.get(multiIndex[index][1])
            # After the change tuning it back into a tuple
            multiIndex[index] = tuple(tempList)

    # Retuning a tuple again
    return tuple(multiIndex)



'''def getReShapedDataframe(df, transformersParameters):
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
#   DBID	HOUR	AAS_PERC90	AAS_PERC95	UT_PERC90	UT_PER95
#   1	0	20	22	450	460
#   1	1	18	19	400	420
#   1	2	18	18	390	400


    hours = df.drop_duplicates(subset=[transformersParameters['CLUSTER_COLUMN']])[transformersParameters['CLUSTER_COLUMN']].tolist()
    metrics = transformersParameters['FROM_TO_ROWS_TO_COLUMNS']

    newShapeDataframe = df[transformersParameters['INDEX_COLUMNS']].copy()
    newBaseShapeDataframe = newShapeDataframe.drop_duplicates()
    newBaseShapeDataframe.reset_index()

    results = {}

    resultsDataframes = {}

    # Most of the times this column will be an HOUR from 0..23. However, that might be cases in which this is the CON_ID or somethihg else
    # This column should always have uniq (Unique Key) combination with the field that will become a column for that given collection. For example:
    # PKEY + HOUR + METRIC_NAME = UNIQUE (UK)
    # PKEY + CON_ID + INITORA_PARAMETER = UNIQUE (UK)
    for hour in hours:

        df_by_hour = df[(df[transformersParameters['CLUSTER_COLUMN']] == hour)]
        newBaseShapeDataframe_by_hour = newBaseShapeDataframe[(newBaseShapeDataframe[transformersParameters['CLUSTER_COLUMN']] == hour)]

        results[hour] = {}

        # Looping on all metrics to become columns. It will be used to filter the dataframe
        for metric in metrics.keys():

            results[hour][metrics.get(metric) + '_PERC95'] = []
            results[hour][metrics.get(metric) + '_PERC90'] = []
      

            # Filterting dataframe per metric which means 1 line per database collection
            df_by_hour_by_metric = df_by_hour[(df_by_hour[transformersParameters['TARGET_COLUMN']] == metric)]

      
            # Looping all lines for the given hour and metric (it will only have multiple lines if there are multiple collections, otherwise, it will be always 1 row)
            for index, row in df_by_hour_by_metric.iterrows():

                # Storing the metric by hour value that will turn into column
                results[hour][metrics.get(metric) + '_PERC95'].append(row['PERC95'])
                results[hour][metrics.get(metric) + '_PERC90'].append(row['PERC90'])

          
            # Creating a new column in the df using a list accordingly with the hour
            newBaseShapeDataframe_by_hour[metrics.get(metric) + '_PERC95'] = results[hour][metrics.get(metric) + '_PERC95']
            newBaseShapeDataframe_by_hour[metrics.get(metric) + '_PERC90'] = results[hour][metrics.get(metric) + '_PERC90']

            resultsDataframes[hour] = newBaseShapeDataframe_by_hour



    # Generating Final Dataframe with all hours and metrics
    finalDF = appendListOfDataframes(resultsDataframes)

    return finalDF


def appendListOfDataframes(dataframesDict):

    count = 0
    for dfIndex in dataframesDict:

        if count == 0:

            df = dataframesDict[dfIndex]
            count = count + 1
            continue

        df.append(dataframesDict[dfIndex])
        count = count + 1

    return df'''

if __name__ == '__main__':

    # Getting parameters and rules from transformers.json
    transformerConfiguration = getRulesFromJSON('db-assessment/transformers.json')

    transformerRulesConfig = transformerConfiguration['rules']
    transformersParametersConfig = transformerConfiguration['parameters']

    transformerParameterResults = {}
    transformersParameters = {}
    transformerParameterResults, transformersParameters = runRules(transformersParametersConfig, None)

    fileList = import_db_assessment.getAllFilesByPattern('/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb*log')
    
    dbAssessmentDataframes = {}
    dbAssessmentDataframes = getAllDataFrames(fileList, 1)

    dbAssessmentDataframes = getAllReShapedDataframes(dbAssessmentDataframes, transformersParameters)

    print(dbAssessmentDataframes.keys())

    transformerParameterResults, transformersParameters = runRules(transformerRulesConfig, dbAssessmentDataframes)

