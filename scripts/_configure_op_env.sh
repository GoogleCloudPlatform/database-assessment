#!/usr/bin/env bash

### Validate input
##############################################################################
echo "Verifying environment before configuring Optimus Prime"

# Fail if these variables are not set
if [ "${PROJECTNAME}" == "" ] || [ -z "${PROJECTNAME}" ]; then
    echo "Please ensure PROJECTNAME environment variable is set properly."
    exit 1
fi
if [ "${DSNAME}" == "" ] || [ -z "${DSNAME}" ]; then
    echo "Please ensure DSNAME environment variable is set properly."
    exit 1
fi
if [ "${DSLOC}" == "" ] || [ -z "${DSLOC}" ]; then
    echo "Please ensure DSLOC environment variable is set properly."
    exit 1
fi
if [ "${OPOUTPUTDIR}" == "" ] || [ -z "${OPOUTPUTDIR}" ]; then
    echo "Please ensure OPOUTPUTDIR environment variable is set properly."
    exit 1
fi
if [ "${COLLECTION_VERSION}" == "" ] || [ -z "${COLLECTION_VERSION}" ]; then
    echo "Please ensure COLLECTION_VERSION environment variable is set properly."
    exit 1
fi


# Default these variables if they are not set.
if [ "${REPORTNAME}" == "" ] || [ -z "${REPORTNAME}" ]; then
    export REPORTNAME="OptimusPrime%20Dashboard%20${DSNAME}"
    echo "REPORTNAME not set, defaulting to ${REPORTNAME}."
fi
if [ "${COLSEP}" == "" ] || [ -z "${COLSEP}" ]; then
    export COLSEP='|'
    echo "COLSEP not set, defaulting to ${COLSEP}"
fi

export OP_WORKING_DIR=$(pwd)

echo
echo Environment set to load from ${OPOUTPUTDIR} into ${PROJECTNAME}.${DSNAME}

if [[ -s ${OPOUTPUTDIR}/opdb__*errors.log ]] 
then
    echo Errors found in data to be loaded.   Please review before continuing.
    cat ${OPOUTPUTDIR}/opdb__*errors.log
fi
