
import pandas as pd

import json


def createTransformersVariable(transformerRule):

    if transformerRule['action_details']['datatype'] == 'DICTIONARY':

        resRule = {}

        print ('\n\nTo be Dictionary: ', str(transformerRule['action_details']['value']))

        resRule = json.loads(str(transformerRule['action_details']['value']).strip())

        return resRule

    else:

        return {}

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

        if transformerRules['rules'][ruleItem]['type'] == "VARIABLE" and transformerRules['rules'][ruleItem]['action'] == "CREATE":

            try:
                transformerResults[ruleItem] = {'Status': EXECUTEDSTATUS, 'Result Value': createTransformersVariable(transformerRules['rules'][ruleItem])}
                transformerVariables[transformerRules['rules'][ruleItem]['action_details']['varname']] = transformerResults[ruleItem]['Result Value']

            # In case of any issue the rule will be marked as FAILEDSTATUS
            except:
                transformerResults[ruleItem] = {'Status': FAILEDSTATUS, 'Result Value': None}
                transformerVariables[transformerRules['rules'][ruleItem]['action_details']['varname']] = None

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


def getAllDataFrames():

    dataFrames = {}
    skipRows = 1

    csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__dbsummary__consolidate.log'
    dbsummary_df = getDataFrameFromCSV(csvFileName,skipRows)
    dataFrames['dbsummary'] = {'dataframe': dbsummary_df}

    #csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__dbsummary__consolidate.log'
    #dboverview_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dboverview'] = {'dataframe': dboverview_df}

    csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__pdbsinfo__consolidate.log'
    pdbsinfo_df = getDataFrameFromCSV(csvFileName,skipRows)
    dataFrames['pdbsinfo'] = {'dataframe': pdbsinfo_df}

    csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__pdbsopenmode__consolidate.log'
    pdbsopenmode_df = getDataFrameFromCSV(csvFileName,skipRows)
    dataFrames['pdbsopenmode'] = {'dataframe': pdbsopenmode_df}

    csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__dbinstances__consolidate.log'
    dbinstances_df = getDataFrameFromCSV(csvFileName,skipRows)
    dataFrames['dbinstances'] = {'dataframe': dbinstances_df}

    #usedspacedetails_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['usedspacedetails'] = {'dataframe': usedspacedetails_df}

    #compressbytable_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['compressbytable'] = {'dataframe': compressbytable_df}

    #compressbytype_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['compressbytype'] = {'dataframe': compressbytype_df}

    #spacebyownersegtype_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['spacebyownersegtype'] = {'dataframe': spacebyownersegtype_df}

    #spacebytablespace_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['spacebytablespace'] = {'dataframe': spacebytablespace_df}

    #freespaces_df = getDataFrameFromCSV(csvFileName,skipRows)
    #ataFrames['freespaces'] = {'dataframe': freespaces_df}

    #dblinks_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dblinks'] = {'dataframe': dblinks_df}

    #dbparameters_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dbparameters'] = {'dataframe': dbparameters_df}

    #dbfeatures_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dbfeatures'] = {'dataframe': dbfeatures_df}

    #dbhwmarkstatistics_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dbhwmarkstatistics'] = {'dataframe': dbhwmarkstatistics_df}

    #cpucoresusage_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['cpucoresusage'] = {'dataframe': cpucoresusage_df}

    #dbobjects_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['dbobjects'] = {'dataframe': dbobjects_df}

    #sourcecode_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['sourcecode'] = {'dataframe': sourcecode_df}

    #partsubparttypes_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['partsubparttypes'] = {'dataframe': partsubparttypes_df}

    #indexestypes_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['indexestypes'] = {'dataframe': indexestypes_df}

    #datatypes_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['datatypes'] = {'dataframe': datatypes_df}

    #tablesnopk_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['tablesnopk'] = {'dataframe': tablesnopk_df}

    #systemstats_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['systemstats'] = {'dataframe': systemstats_df}

    #patchlevel_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['patchlevel'] = {'dataframe': patchlevel_df}

    csvFileName = '/Users/erisantos/cloud-source-repo/optimus-prime-db-assessment/dbResults/opalldb__awrhistsysmetrichist__consolidate.log'
    awrhistsysmetrichist_df = getDataFrameFromCSV(csvFileName,skipRows)
    dataFrames['awrhistsysmetrichist'] = {'dataframe': awrhistsysmetrichist_df}

    #awrhistsystimemodel_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['awrhistsystimemodel'] = {'dataframe': awrhistsystimemodel_df}

    #awrhistosstat_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['awrhistosstat'] = {'dataframe': awrhistosstat_df}

    #awrhistcmdtypes_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['awrhistcmdtypes'] = {'dataframe': awrhistcmdtypes_df}

    #optimusconfig_bms_machinesizes_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['optimusconfig_bms_machinesizes'] = {'dataframe': optimusconfig_bms_machinesizes_df}

    #optimusconfig_network_to_gcp_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['optimusconfig_network_to_gcp'] = {'dataframe': optimusconfig_network_to_gcp_df}

    #alertlog_df = getDataFrameFromCSV(csvFileName,skipRows)
    #dataFrames['alertlog'] = {'dataframe': alertlog_df}

    return dataFrames

def swapDbAssessmentRowsToColumns(dbAssessmentDataframe,swapRowsToColumns,colsDataframeShort,swapColumns):

    dbAssessmentDataframeShort = dbAssessmentDataframe[colsDataframeShort].copy()

    columnName = None

    for index, row in dbAssessmentDataframe.iterrows():

        # If there is a match is because this row supposed to be swapped
        columnName = swapRowsToColumns.get(str(row['METRIC_NAME']).strip())

        if columnName is not None:

            # Columns that we want to keep in the dataFrame
            for column in swapColumns:

                columnName = columnName + '_' + column

                dbAssessmentDataframeShort[columnName] = row['']

if __name__ == '__main__':

    # Call main function
    transformerRules = getRulesFromJSON('transformers.json')

    transformerResults = {}
    transformerVariables = {}
    transformerResults, transformerVariables = runRules(transformerRules, None)

    print (transformerResults)
    print (transformerVariables)

    dbAssessmentDataframes = {}
    dbAssessmentDataframes = getAllDataFrames()

    colsDataframeShort = ['PKEY','CON_ID','DBID','INSTANCE_NUMBER']
    swapRowsToColumns = {"I/O Megabytes per Second": "IOMBPS", "I/O Requests per Second": "IOPS"}
    swapColumns = ['PERC90','PERC95','PERC100']
    swapDbAssessmentRowsToColumns(dbAssessmentDataframes['awrhistsysmetrichist']['dataframe'], swapRowsToColumns, colsDataframeShort, swapColumns)


