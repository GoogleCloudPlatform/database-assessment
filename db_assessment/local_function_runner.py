# Rules engine
import rules_engine
import import_db_assessment
import sys, os

OP_WORKDING_DIR="/Users/sandeepmanocha/github_repos"
OP_BQ_DATASET="sandeep"
OP_OUTPUT_DIR= OP_WORKDING_DIR + "/oracle-database-assessment-output"

def renamefiles():
    fileslocation = OP_OUTPUT_DIR
    collectionid = "020222210706"
    csvFilesLocationPattern = str(fileslocation) + '/*' + str(collectionid).replace(' ','') + '.log'
    fileList = import_db_assessment.getAllFilesByPattern(csvFilesLocationPattern)
    #print(fileList)
    for filename in fileList:
        new_filename = filename.replace("multitenant.DB19C","multitenant.DB_19C")
        os.rename(filename, new_filename)
    print("Done")

def files():
    # Optimus Prime Search Pattern to find the target CSV files to be processed
    # The default location will be dbResults if not overwritten by the argument -fileslocation

    fileslocation = OP_OUTPUT_DIR
    collectionid = "020222210706"
    csvFilesLocationPattern = str(fileslocation) + '/*' + str(collectionid).replace(' ','') + '.log'
    #print("csvFilesLocationPattern is ", csvFilesLocationPattern)

    # Getting a list of files from OS based on the pattern provided
    # This is the default directory to have all customer database results from oracle_db_assessment.sql
    fileList = import_db_assessment.getAllFilesByPattern(csvFilesLocationPattern)
    # mock is there is _ in  dbname for e.g DB_19C
    fileName = "/Users/sandeepmanocha/github_repos/oracle-database-assessment-output/opdb__awrhistsysmetricsumm__190_2.0.3_vm-orcl-19c-multitenant.DB_19C.db19c.020222210706.log"
    fileList[0] = fileName
    collectionType = import_db_assessment.getObjNameFromFiles(str(fileList[0]),'__',0)
    tableName = import_db_assessment.getObjNameFromFiles(fileName,'__',1)
    collectionKey = import_db_assessment.getObjNameFromFiles(str(fileList[0]),'__',2)

    print("fileName is {}".format(fileName))
    print("collectionType:{}".format(collectionType))
    print("tableName:{}".format(tableName))
    print("collectionKey:{}".format(collectionKey))

    collectionKey_parts = collectionKey.split('_')
    dbversion = None
    optimuscollectionversion = collectionKey_parts[1]
    pkey = collectionKey_parts[2]
    print("dbversion:{}, optimuscollectionversion:{}, pkey:{}".format(dbversion, optimuscollectionversion, pkey))
    #print(fileList)

    # Verify if the script has any version on it (only old script versions should not have 3 parts)
    
    print("len collectionKey:{}".format(str(len(collectionKey_parts))))
    if len(collectionKey.split('_')) >= 3 and dbversion is None: # TODO: fix bug #23
        dbversion = collectionKey_parts[0]    
        print("Here in Memphis. Assign {} as dbversion".format(collectionKey_parts[0]))
    else:
        print ('\nFATAL ERRROR: Please use -dbversion and -collectionversion. \nI.E -dbversion 122 -collectionversion 2.0.3\n')
        sys.exit()

    # Getting file pattern for find config files in the OS to be imported
    csvFilesLocationPatternOPConfig = 'opConfig/*.csv'

    # Getting a list of files from OS based on the pattern provided
    fileListOPConfig = import_db_assessment.getAllFilesByPattern(csvFilesLocationPatternOPConfig)
    #print(fileListOPConfig)


def transformer():
    # Import Json with parameters and rules
    transformersconfig = "/Users/sandeepmanocha/github_repos/oracle-database-assessment/db_assessment/opConfig/transformers.json"
    transformerConfiguration = rules_engine.getRulesFromJSON(str(transformersconfig))
    for config in transformerConfiguration.items():
        for rule in config:
            print(type(rule))


if __name__ == '__main__':
    print("OP_WORKDING_DIR",OP_WORKDING_DIR)
    print("OP_BQ_DATASET",OP_BQ_DATASET)
    print("OP_OUTPUT_DIR",OP_OUTPUT_DIR)
    renamefiles()