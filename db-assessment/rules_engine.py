
import pandas as pd

import json

import import_db_assessment

def createTransformersVariable(transformerRule):

    if str(transformerRule['action_details']['datatype']).upper() == 'DICTIONARY':

        return json.loads(str(transformerRule['action_details']['value']).strip())

    elif str(transformerRule['action_details']['datatype']).upper() == 'LIST':

        return str(transformerRule['action_details']['value']).split(',')

    elif str(transformerRule['action_details']['datatype']).upper() == 'STRING':

        return str(transformerRule['action_details']['value'])

    elif str(transformerRule['action_details']['datatype']).upper() == 'NUMBER':

        return float(transformerRule['action_details']['value'])

    else:

        return None

def runRules(transformerRules, dataFrames):

    # Variable to keep track of rules executed and its results and status
    transformerResults = {}
    # Variable to keep track and make available all the variables from the JSON file
    transformerVariables = {}

    # Standardize Statuses
    # Executed
    EXECUTEDSTATUS = 'EXECUTED'
    FAILEDSTATUS = 'FAILED'

    # Looping on ALL rules from transformers.json
    for ruleItem in transformerRules['rules']:

        if str(transformerRules['rules'][ruleItem]['type']).upper() == "VARIABLE" and str(transformerRules['rules'][ruleItem]['action']).upper() == "CREATE":
        # transformers.json asking to create a variable which is a dictionary

            try:
                transformerResults[ruleItem] = {'Status': EXECUTEDSTATUS, 'Result Value': createTransformersVariable(transformerRules['rules'][ruleItem])}
                transformerVariables[transformerRules['rules'][ruleItem]['action_details']['varname']] = transformerResults[ruleItem]['Result Value']

            # In case of any issue the rule will be marked as FAILEDSTATUS
            except:
                transformerResults[ruleItem] = {'Status': FAILEDSTATUS, 'Result Value': None}
                transformerVariables[transformerRules['rules'][ruleItem]['action_details']['varname']] = None

        elif str(transformerRules['rules'][ruleItem]['type']).upper() == "NUMBER" and str(transformerRules['rules'][ruleItem]['action']).upper() == "ADD_COLUMN":
        # transformers.json asking to add a column that is type number meaning it can be a calculation and the column to be added is NUMBER too

            None

    return transformerResults, transformerVariables

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

    df = pd.read_csv(csvFileName, skiprows=skipRows)

    return df


def getAllDataFrames(fileList, skipRows):
# Fuction to read from CSVs and store the data into a dataframe. The dataframe is placed then into a Hash Table.

    # Hash table to store dataframes after being loaded from CSVs
    dataFrames = {}

    for fileName in fileList:

        # Final table name from the CSV file names
        tableName = import_db_assessment.getObjNameFromFiles(fileName,'__',1)

        # Storing Dataframe in a Hash Table using as a key the final Table name coming from CSV filename
        df = getDataFrameFromCSV(fileName,skipRows)
        # Trimming the data before storing it
        dataFrames[tableName] = trimDataframe(df)


    return dataFrames

def trimDataframe(df):

    # Removing spaces (TRIM/Strip) for ALL columns
    cols = list(df.columns)
    df[cols] = df[cols].apply(lambda x: x.str.strip())

    # trimmed dataframe
    return df

def getAllReShapedDataframes(dataFrames, targetTableNames):
    # Function to iterate on getReShapedDataframe to reShape some dataframes accordingly with targetTableNames
    # dataFrames is expected to be a Hash Table of dataframes
    # targetTableNames is expected to be a list with the right keys from the Hash table dataFrames

    for tableName in targetTableNames:

        getReShapedDataframe(dataFrames[tableName], )

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


    hours = df.drop_duplicates(subset=['HO'])['HO'].tolist()
    metrics = {'User Transaction Per Sec': 'USPS','SQL Service Response Time': 'SQLRT','Redo Generated Per Sec': 'RGPS'}

    newShapeDataframe = df[['PKEY', 'CON_ID', 'DBID','INSTANCE_NUMBER','HO']].copy()
    newBaseShapeDataframe = newShapeDataframe.drop_duplicates()

    results = {}

    resultsDataframes = {}

    # Most of the times this column will be an HOUR from 0..23. However, that might be cases in which this is the CON_ID or somethihg else
    # This column should always have uniq (Unique Key) combination with the field that will become a column for that given collection. For example:
    # PKEY + HOUR + METRIC_NAME = UNIQUE (UK)
    # PKEY + CON_ID + INITORA_PARAMETER = UNIQUE (UK)
    for hour in hours:

        df_by_hour = df[(df['HO'] == hour)]
        newBaseShapeDataframe_by_hour = newBaseShapeDataframe[(newBaseShapeDataframe['HO'] == hour)]

        results[hour] = {}

        # Looping on all metrics to become columns. It will be used to filter the dataframe
        for metric in metrics.keys():

            results[hour][metrics.get(metric) + '_PERC95'] = []
            results[hour][metrics.get(metric) + '_PERC90'] = []
      

            # Filterting dataframe per metric which means 1 line per database collection
            df_by_hour_by_metric = df_by_hour[(df_by_hour['METRIC_NAME'] == metric)]

      
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


def appendListOfDataframes(dataframesList):

    for dfIndex in len(dataframesList):

        if dfIndex == 0:

            df = dataframesList[dfIndex]
            continue

        df.append(dataframesList[dfIndex])

    return df

if __name__ == '__main__':

    # Call main function
    transformerRules = getRulesFromJSON('transformers.json')

    transformerResults = {}
    transformerVariables = {}
    transformerResults, transformerVariables = runRules(transformerRules, None)

    print (transformerResults)
    print (transformerVariables)

    fileList = import_db_assessment.getAllFilesByPattern('/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb*log')
    dbAssessmentDataframes = {}
    dbAssessmentDataframes = getAllDataFrames(fileList, 1)

    colsDataframeShort = ['PKEY','CON_ID','DBID','INSTANCE_NUMBER']
    swapRowsToColumns = {"I/O Megabytes per Second": "IOMBPS", "I/O Requests per Second": "IOPS"}
    swapColumns = ['PERC90','PERC95','PERC100']
    #swapDbAssessmentRowsToColumns(dbAssessmentDataframes['awrhistsysmetrichist']['dataframe'], swapRowsToColumns, colsDataframeShort, swapColumns)


