# This script will verify that all the OS commands and utilities are available prior to running the DMA collector.
. ./dma_print_pass_fail.sh
echo
echo Checking for availability of all operating system commands and utilities required for the DMA collector.
echo Required commands and utilities are:
echo   cut    
echo   dirname
echo   grep   
echo   gzip   
echo   iconv  
echo   md5sum 
echo   sed    
echo   sqlplus
echo   tar    
echo   tr     
echo   uname  
echo   zip    

FAIL=0

THISSHELL=${SHELL}
SCRIPTCOMMAND=${BASH_SOURCE[0]}
SQLPLUS=$(which sqlplus)
GREP=$(which grep 2>/dev/null)
SED=$(which sed 2>/dev/null)
MD5SUM=$(which md5sum 2>/dev/null)
ZIP=$(which zip 2>/dev/null)
GZIP=$(which gzip 2>/dev/null)
TAR=$(which tar 2>/dev/null)
ICONV=$(which iconv 2>/dev/null)
TR=$(which tr 2>/dev/null)
CUT=$(which cut 2>/dev/null)
UNAME=$(which uname 2>/dev/null)
DIRNAME=$(which dirname 2>/dev/null)

# If BASH_SOURCE is null, assume we are in ksh
if [ "${SCRIPTCOMMAND}" = "" ]
  then
    SCRIPTCOMMAND="${.sh.file}"
fi


if [ "${ICONV}" = "" ]
  then
    echo Missing command iconv 
    FAIL=$(($FAIL + 1))
fi

if [ "${TR}" = "" ]
  then
    echo Missing command tr
    FAIL=$(($FAIL + 1))
fi

if [ "${CUT}" = "" ]
  then
    echo Missing command cut
    FAIL=$(($FAIL + 1))
fi


if [ "${UNAME}" = "" ]
  then
    echo Missing command uname
    FAIL=$(($FAIL + 1))
fi

if [ "${DIRNAME}" = "" ]
  then
    echo Missing command dirname
    FAIL=$(($FAIL + 1))
fi


if [ "$(uname)" = "SunOS" ]
then
      GREP=/usr/xpg4/bin/grep
      SED=/usr/xpg4/bin/sed
fi

if [ "$(uname)" = "HP-UX" ]; then
  if [ -f /usr/local/bin/md5 ]; then
    MD5SUM=/usr/local/bin/md5
  fi
fi

if [ "${ZIP}" = "" ]
 then
   if [ "${GZIP}" = "" ]
     then
       echo There is no zip or gzip available.
       FAIL=$(($FAIL + 1))
     else 
       if [ "${TAR}" = "" ]
         then
           echo There is no zip available.  Found gzip but no tar.
           echo If the system does not have zip installed, it must have tar and gzip.
           FAIL=$(($FAIL + 1))
       else
           echo There is no zip available, so we will use tar and gzip.
       fi
   fi
fi


# Check if running on Windows Subsystem for Linux
ISWIN=$(uname -a | grep -i microsoft |wc -l)
if [ ${ISWIN} -eq 1 ]
  then
	  SQL_DIR=$(wslpath -a -w ${SCRIPT_DIR})/sql
          SQLOUTPUT_DIR=$(wslpath -a -w ${SQLOUTPUT_DIR})
	  SQLPLUS=$(which sqlplus.exe 2>/dev/null)
fi

# Check if running on Cygwin
ISCYG=$(uname -a | grep -i cygwin | wc -l)
if [ ${ISCYG} -eq 1 ]
 then
	  SQL_DIR=$(cygpath -w ${SCRIPT_DIR})/sql
          SQLOUTPUT_DIR=$(cygpath -w ${SQLOUTPUT_DIR})
	  SQLPLUS=$(which sqlplus.exe 2>/dev/null)
fi

if [ "${SQLPLUS}" = "" ]
  then
    echo SQL*Plus not found on this machine.  Ensure sqlplus is installed and in the path.
    FAIL=$(($FAIL + 1))
fi

echo
#echo RESULTS:
#echo "cut     is available at $CUT"
#echo "dirname is available at $DIRNAME"
#echo "grep    is available at $GREP"
#echo "gzip    is available at $GZIP"
#echo "iconv   is available at $ICONV"
#echo "md5sum  is available at $MD5SUM"
#echo "sed     is available at $SED"
#echo "sqlplus is available at $SQLPLUS"
#echo "tar     is available at $TAR"
#echo "tr      is available at $TR"
#echo "uname   is available at $UNAME"
#echo "zip     is available at $ZIP"
#echo
#echo "shell is $SHELL"
#echo "This script is ${SCRIPTCOMMAND}"
echo
if [ ${FAIL} -eq 0 ]
  then 
    echo
    print_pass
    echo "All operating system checks passed."
    echo
  else
    echo
    print_fail
    echo Failed $FAIL tests
    echo Address the issues above and retry.
fi



