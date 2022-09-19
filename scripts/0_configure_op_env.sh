#!/usr/bin/env bash

### Validate input
##############################################################################
echo "Verifying environment before configuring Optimus Prime"

# Fail if these variables are not set
if [ "${PROJECTNAME}" == "" ]; then
    echo "Please ensure PROJECTNAME is set properly."
    return
fi
if [ "${DSNAME}" == "" ]; then
    echo "Please ensure DSNAME is set properly."
    return
fi
if [ "${DSLOC}" == "" ]; then
    echo "Please ensure DSLOC is set properly."
    return
fi
if [ "${OP_LOG_DIR}" == "" ]; then
    echo "Please ensure OP_LOG_DIR is set properly."
    return
fi


# Default these variables if they are not set.
if [ "${REPORTNAME}" == "" ]; then
    export REPORTNAME="OptimusPrime%20Dashboard%20${DSNAME}"
    echo "REPORTNAME not set, defaulting to ${REPORTNAME}."
fi
if [ "${COLSEP}" == "" ]; then
    export COLSEP='|'
    echo "COLSEP not set, defaulting to ${COLSEP}"
fi


export OP_WORKING_DIR=$(pwd)

echo
echo Environment set to load from ${OP_LOG_DIR} into ${PROJECTNAME}.${DSNAME}

if [[  -s ${OP_LOG_DIR}/errors*.log ]] 
then
	echo Errors found in data to be loaded.   Please review before continuing.
	cat ${OP_LOG_DIR}/errors*.log
fi
