# This file configures the environemt for loading data files from the client
# Edit this file and set the project name, data set name, and data set location to
# where you want the data loaded.
# Ensure you have proper access to the project and rights to create a data set.

# This is the name of the project into which you want to load data
export PROJECTNAME=yourProjectNameHere

# This is the name of the data set into which you want to load. 
# The dataset will be created if it does not exist.
# If the datset already exists, it will have this data appoended.
# Use only alphanumeric characters, - (dash) or _ (underscore)
# This name must be filesystem and html compatible
export DSNAME=yourDatasetNameHere

# This is the location in which the dataset should be created.  
export DSLOC=yourRegionNameHere

# This is the full path into which the customer's files have been extracted.
export OP_LOG_DIR=fullPathToLogFiles

# This is the name of the report you want to create in DataStudio upon load completion.
# Use only alphanumeric characters or embed HTML encoding.
export REPORTNAME="OptimusPrime%20Dashboard%20${DSNAME}"

# This is the column separator used in the customer's files.  Older versions of 
# the extract will use semicolon, newer versions will use pipe.
export COLSEP='|'


export OP_WORKING_DIR=$(pwd)

echo
echo Environment set to load from ${OP_LOG_DIR} into ${PROJECTNAME}.${DSNAME}

if [[  -s ${OP_LOG_DIR}/errors*.log ]] 
then
	echo Errors found in data to be loaded.   Please review before continuing.
	cat ${OP_LOG_DIR}/errors*.log
fi
