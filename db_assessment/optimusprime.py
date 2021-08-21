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


# Basic python built-in libraries to enable read, write and manipulate files in the OS
import os
import glob
import sys

# Manages command line flags and arguments
import argparse

# Setting client info for Google APIs
import set_client_info

# Import to Big Query
import import_db_assessment

# Rules engine
import rules_engine

# Importing Optimus Prime Version
import version

# Information for analytics and tool improvement
__version__= version.__version__

# Messages handling
import logging
logging.getLogger().setLevel(level=logging.INFO)


def getVersion():

    return __version__


def runMain(args):
# Main function

    # Pre-Tasks before trying to import any data

    # STEP: Readin JSON file configuration (rules and parameters)

    # Import Json with parameters and rules
    transformerConfiguration = rules_engine.getRulesFromJSON(str(getattr(args,'transformersconfig')))

    # Assigning the rules and parameter {} variables
    transformerRulesConfig = {}
    transformerRulesConfig = transformerConfiguration['rules']
    transformersParameters = {}
    transformersParameters = transformerConfiguration['parameters']
    transformersTablesSchema = None
    transformersTablesSchemaConfig = {}
    transformersTablesSchemaConfig = transformerConfiguration['tableschemas']

    
    # For all cases in which those attributes are <> None it means the user wants to import data to Big Query
    # No need to further messaging for mandatory options because this is being done in argumentsParser function
    if getattr(args,'dataset') is not None and getattr(args,'collectionid') is not None:


        # This is broken needs to be fixed in upcoming versions
        if getattr(args,'consolidatelogs'):
            # It is True if no fatal errors were found
            resConsolidation = import_db_assessment.consolidateLos(args,transformersTablesSchema)



        # STEP 1: Import customer database assessment data

        # Optimus Prime Search Pattern to find the target CSV files to be processed
        # The default location will be dbResults if not overwritten by the argument -fileslocation
        csvFilesLocationPattern = str(getattr(args,'fileslocation')) + '/*' + str(getattr(args,'collectionid')).replace(' ','') + '.log'

        # Getting a list of files from OS based on the pattern provided
        # This is the default directory to have all customer database results from oracle_db_assessment.sql
        fileList = import_db_assessment.getAllFilesByPattern(csvFilesLocationPattern)

        # In case there is no matching file in the OS
        if len(fileList) == 0:
            sys.exit('\nERROR: There is not matching CSV file found to be processed using: {}\n'.format(csvFilesLocationPattern))

        # Getting file pattern for find config files in the OS to be imported
        csvFilesLocationPatternOPConfig = 'opConfig/*.csv'

        # Getting a list of files from OS based on the pattern provided
        fileListOPConfig = import_db_assessment.getAllFilesByPattern(csvFilesLocationPatternOPConfig)

        # Variable to track the collection id. To be used mostly when new CSV files are generated from processing rules
        collectionKey = import_db_assessment.getObjNameFromFiles(str(fileList[0]),'__',2)
        transformersParameters['collectionKey'] = collectionKey

        # Verify if the script has any version on it (only old script versions should not have 3 parts)
        if args.dbversion is not None:
            transformersParameters['dbversion'] = str(args.dbversion)
        elif len(collectionKey.split('_')) == 3 and args.dbversion is None:
            transformersParameters['dbversion'] = import_db_assessment.getObjNameFromFiles(collectionKey,'_',0)
        else:
            print ('\nFATAL ERRROR: Please use -dbversion.\n')
            sys.exit()

        if len(collectionKey.split('_')) == 3:
            transformersParameters['optimuscollectionversion'] = import_db_assessment.getObjNameFromFiles(collectionKey,'_',1)
        else:
            transformersParameters['optimuscollectionversion'] = args.collectionversion

        # If this valus is set it has precende over everything else
        if args.collectionversion != '0.0.0':
            transformersParameters['optimuscollectionversion'] = args.collectionversion

        print('\nSource Database Version: {} \nCollection Script Version: {}\n'.format(transformersParameters['dbversion'],transformersParameters['optimuscollectionversion']))

        try:
            # Adjusting the tableschemas from transformers.json accordingly with the database version
            for dbVersion in transformersTablesSchemaConfig[transformersParameters['optimuscollectionversion']].keys():

                if transformersParameters['dbversion'] in dbVersion:
                    transformersTablesSchema = transformersTablesSchemaConfig[transformersParameters['optimuscollectionversion']][dbVersion]

            # If we could not find any matching for tableSchemas
            if transformersTablesSchema is None:
                print('\n FAILURE: Optimus Prime could not find in transformers.json matching for table schema configuration for "optimuscollectionversion={}" and "dbversion={}"\n'.format(transformersParameters['optimuscollectionversion'],transformersParameters['dbversion']))
                sys.exit()
        except KeyError:
            print('\n FAILURE: Optimus Prime could not find in transformers.json matching for table schema configuration for "optimuscollectionversion={}" and "dbversion={}"\n'.format(transformersParameters['optimuscollectionversion'],transformersParameters['dbversion']))
            sys.exit()
        
        # Import the CSV files into Big Query
        gcpProjectName = getattr(args,'projectname')
        bqDataset = str(getattr(args,'dataset'))
        
        # Delete the dataset before importing new data
        if args.deletedataset:
            if args.projectname is not None:
                import_db_assessment.deleteDataSet(bqDataset,gcpProjectName)
            else:
                sys.exit('\nWARNING: The database {} will not be deleted because the option -projectname is omitted. \nPlease try again either providing -projectname OR removing -deletedataset.\n\n'.format(args.deletedataset))
        
        # Create the dataset to import the CSV data
        import_db_assessment.createDataSet(bqDataset,gcpProjectName)

        


        # STEP: Processing parameters which create internal variables(transformersParameters) to be used in later stages

        #####transformerParameterResults, transformersParameters = rules_engine.runRules(transformerRulesConfig, None, None)

        # STEP: Loading all CSV files in memory into dataframes

        dbAssessmentDataframes = {}
        dbAssessmentDataframes, transformersTablesSchema = rules_engine.getAllDataFrames(fileList, 1, collectionKey, args, transformersTablesSchema, dbAssessmentDataframes, transformersParameters)
        dbAssessmentDataframes, transformersTablesSchema = rules_engine.getAllDataFrames(fileListOPConfig, 0, collectionKey, args, transformersTablesSchema, dbAssessmentDataframes, transformersParameters)

        # STEP: Reshape Dataframes when necessary based on the transformersParameters

        dbAssessmentDataframes, fileList, transformersTablesSchema, rulesAlreadyExecuted = rules_engine.getAllReShapedDataframes(dbAssessmentDataframes, transformersTablesSchema, transformersParameters, transformerRulesConfig, args, collectionKey, fileList)

        # STEP: Run rules engine

        transformerParameterResults, transformersRulesVariables, fileList, dbAssessmentDataframes = rules_engine.runRules(transformerRulesConfig, dbAssessmentDataframes, None, args, collectionKey, transformersTablesSchema, fileList, rulesAlreadyExecuted, transformersParameters)


        # STEP: Import ALL data to Big Query

        # Eliminating duplicated entries from transformers.json processing
        fileList = list(set(fileList))

        if args.fromdataframe:

            sucessImported, tablesImported = import_db_assessment.importAllDataframeToBQ(args,gcpProjectName,bqDataset,transformersTablesSchema,dbAssessmentDataframes)

        else:

            # Import the CSV data found in the OS
            import_db_assessment.importAllCSVsToBQ(gcpProjectName,bqDataset,fileList,transformersTablesSchema,2,transformersParameters)
            # Import all Optimus Prime CSV configutation
            import_db_assessment.importAllCSVsToBQ(gcpProjectName,bqDataset,fileListOPConfig,transformersTablesSchema,1,transformersParameters)

        # Create Optimus Prime Views
        import_db_assessment.createOptimusPrimeViews(gcpProjectName,bqDataset)

def argumentsParser():
# function to handle all arguments to be used in cli mode for this code and enforces mandatory options

    # Creating an argpaser object
    parser = argparse.ArgumentParser()

    # Name of dataset to be created and have the data imported
    parser.add_argument("-dataset", type=str, default=None, help="name of the Big Query dataset to import all CSV files. If do not exists it will be created if exists the data is appended")

    # GCP project name to be used with the dataset
    parser.add_argument("-projectname", type=str, default=None, help="name of the Google Cloud project name used for the Big Query dataset")

    # OS csv files location to be imported to Big Query
    parser.add_argument("-fileslocation", type=str, default='dbResults', help="optimus prime files location to be imported")

    # OS csv files location to be imported to Big Query
    parser.add_argument("-transformersconfig", type=str, default='opConfig/transformers.json', help="location of transformers.json file with all parameters and rules")

    # Optimus collection ID is the number in the final part of the generated CSV files. For example: dbResults/opdb_dbfeatures_ol79-orcl-db02.ORCLCDB.ORCLCDB.180603.log. Collection ID is: 180603
    parser.add_argument("-collectionid", type=str, default=None, help="optimus prime collection id from CSV files OR 'consolidate' for consolidated logs")

    # Separator for the logs being processed
    parser.add_argument("-sep","-separator", type=str, default=',', help="separator string in the files to be processed")

    parser.add_argument("-dbversion", type=str, default=None, help="database version to be processed")

    parser.add_argument("-collectionversion", type=str, default='0.0.0', help="script collection version used")
    

    parser.add_argument("-schemadetection", type=str, default='FILLGAP', help="How Optimus Prime will handle table schemas to be imported to Big Query")
    # Auto: Uses the columns found in the CSV file to import the data to BQ
    # Manual: Uses the configuration file from JSON
    # FillGaps: Uses manual and whenever a schema is missing then we use Auto for that

    # If this is present in the command line it will take value as true otherwise it will always be false
    parser.add_argument("-deletedataset", default=False, help="Delete dataset before importing new data. WARNING: It will delete all data in the dataset!", action="store_true")

    parser.add_argument("-fromdataframe", default=False, help="Import dataframes to Big Query instead of CSV files.", action="store_true")
    

    # Consolidates different collection IDs found in the OS (dbResults/*log) into a single CSV per file type. 
    # For example: dbResults has 52 files. Meaning, 2 collection IDs (each one has 26 different file types). 
    # After the consolidation it produces 26 *consolidatedlogs.log which would have data from both collection IDs 
    parser.add_argument("-cl", "--consolidatelogs", default=False, help="consolidate all CSV files opdb*log found in dbResults/ directory", action="store_true")

    # Increase logging output level
    parser.add_argument("-v", "--verbose", help="increase output verbosity", action="store_true")

    # Execute the parse_args() method. Variable args is a namespace type
    args = parser.parse_args()

    # If not using -cl flag
    if args.consolidatelogs == False:

        # In case there is not dataset parameter set or with valid content in the arguments
        if (args.dataset is None or args.dataset == ''):
            sys.exit('\nERROR: The parameter -dataset cannot be omitted and it must have a valid name.\n')
        
        # In case project name/project id is not provided
        elif args.projectname is None:
            print ('\nWARNING: Google Cloud project name not provided. Optimus Prime will try to get it automatically from Google Big Query API call.\n')

        # In case optimus collection id is omitted
        elif args.collectionid is None:
            sys.exit('\nERROR: The parameter -collectionid cannot be omitted. Please provide the collection id from CSV files.\n')

    # Returns a namespace object with all arguments and its values
    return args

if __name__ == '__main__':

    # Handling arguments
    args = argumentsParser()

    # Call main function
    runMain(args)
