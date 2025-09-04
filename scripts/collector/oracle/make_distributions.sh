#!/bin/bash 

# Generate all combinations of single-purpose collectors.
OUTPUTBASEDIR=dist

SED='sed -i '
if [[ "Darwin" = "$(uname)" ]];
then
  SED='sed -i bak'
fi

AWKCMD='
print $0
'

# Copy the specified file to the target location and replace all SQL*Plus substitution variables with values from the parameter files.
function gen_file {
    fname="$1"
    destdir="$2"
    fdir=$(dirname ${fname})
    mkdir -p ${destdir}/${fdir}
    outfile=${destdir}/${fname}
    cp ${fname} ${outfile}
    sedsep=""
    sedcmd=""

    # The order of application is important.  Do not change the order of the variable* files.
    for varfile in variables_${dbver}.txt variables_${umf}.txt  variables_${tenant}.txt variables_${stats}.txt variables_ALL.txt
    do 
       sedcmd=""
       sedsep=""
       while read -r subvarline 
       do
         subvar=$(echo ${subvarline} | cut -d ':' -f 1 | tr -d ' ' | tr -d '&' | tr -d '.' )
         subval=$(echo ${subvarline} | cut -d ':' -f 2 | sed 's/^ *//;s/ *$//' )
         # echo ${subvar} '=' ${subval}
         sedcmd="${sedcmd}${sedsep}s/\&${subvar}\./${subval}/g"
         sedsep=";"
       done < <(grep -h -v -e '^#' -e '^--' -e '^$'  ${varfile}  )
       sed -i bak  "${sedcmd}" ${outfile} 
       rm ${outfile}bak 
    done

}

# Replace all SQL*Plus includes with the contents of the file
function replace_includes {
    fname="$1"
    destdir="$2"
    fdir=$(dirname ${fname})

    awk -v basedir=${destdir} -f- $1 > awktmp <<'EOF'
/^ *@/ {
  filename = substr($0, 2) 
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", filename)
  if (filename != "") {
    filename = basedir "/"  filename
    while ((getline line < filename) > 0) {
       if (line !~ /^--/)  {print line}
    }
    close(filename)
  } else {
    print $0 
  }
  next 
}
{
  print $0 
}
EOF
     mv awktmp ${fname}
}

function make_target {
  line="${1}"
  dbver=$(echo $line | cut -d ',' -f 1)
  tenant=$(echo $line | cut -d ',' -f 2)
  stats=$(echo $line | cut -d ',' -f 3)
  statsdir=$(echo $stats | tr [:upper:] [:lower:])
  umf=$(echo $line | cut -d ',' -f 4)
  outputdir=${OUTPUTBASEDIR}/${dbver}/${tenant}/${stats}/${umf}/oracle

  echo Generating :  $dbver $tenant $stats $umf $outputdir

  echo Writing to : ${outputdir}
  mkdir -p ${outputdir}

  # Generate output files from the extracts directory.
  for fname in $(find sql/extracts -maxdepth 1 -type f )
  do
    gen_file "${fname}" "${outputdir}"
  done

  # Generate output files for the chosen stats type
  for fname in $(find sql/extracts/${statsdir} -maxdepth 1 -type f )
  do
    gen_file "${fname}" "${outputdir}"
  done

  # Copy other files needed for testing with the existing collector scripts.
  cp  sql/op_sed_cleanup.sed ${outputdir}/sql
  cp  sql/op_set_sql_env.sql ${outputdir}/sql

  # Copy the conditional driving SQL files for the specified tenancy
  case "${tenant}" in
   "MULTI")
      gen_file sql/op_collect_tenancy_multi.sql "${outputdir}"
      ;;
   "SINGLE")
      gen_file sql/op_collect_tenancy_single.sql "${outputdir}"
      ;;
  esac

  # Copy the conditional driving SQL files for the specified stats type
  case "${stats}" in
   "AWR")
      gen_file sql/op_collect_stats_awr.sql "${outputdir}"
      gen_file sql/extracts/statspack/awrhistosstat.sql "${outputdir}"
      cp  sql/prompt_awr.sql ${outputdir}/sql
      ;;
   "NOSTATS")
      cp  sql/op_collect_stats_nostats.sql ${outputdir}/sql
      cp  sql/prompt_nostats.sql ${outputdir}/sql
      ;;
   "STATSPACK")
      gen_file sql/op_collect_stats_statspack.sql "${outputdir}"
      cp  sql/prompt_statspack.sql ${outputdir}/sql
      ;;
  esac

  # Copy the remaining files
  cp -r sql/setup ${outputdir}/sql
  cp sql/op_collect_init.sql ${outputdir}/sql
  cp collect-data.sh ${outputdir}
  cp README.txt ${outputdir}

  # Copy the automation directory.  (Exclude this? )
  #cp -r automation ${outputdir}

  # Generate the driver SQL files.
  gen_file sql/op_collect.sql "${outputdir}"

  # Replace all the includes with the contents of the referenced file.
  for fname in $(grep -l -r '@' ${outputdir}/sql/extracts)
  do 
    replace_includes $fname ${outputdir}
  done
}

function printUsage
{
echo " Usage:"
echo "  Parameters"
echo ""
echo "  --maxParallel   (Optional)  Number of build threads to run in parallel.  Default is 4. "
echo ""
echo "  --configFile    (Optional)  The name of the files listing the targets to build.  Default is 'distributions.config'. "
echo ""
echo "  --target        (Optional)  The name of a target to build, if you do not want to build everything in the distributions.config file. Will build all targets that contain the string specified. "
echo ""
echo ""
echo " Example:"
echo
echo "  To build everything in the build.confg file and limit parallelism to 2:"
echo "  ./make_distributions.sh --maxParallel 2"
echo ""
echo "  To build all targets for Oracle 19:"
echo "  ./make_distributions.sh --target 190 "
echo
}



### Validate input


 if [[ $(($# & 1)) == 1 ]] ;
 then
  echo "Invalid number of parameters "
  printUsage
  exit
 fi

 while (( "$#" )); 
 do
	 if   [[ "$1" == "--maxParallel" ]];           then MAXPARALLEL="${2}"
	 else if   [[ "$1" == "--configFile" ]];       then CONFIGFILE="${2}"
	 else if   [[ "$1" == "--target" ]];           then TARGET="${2}"
	 else
		 echo "Unknown parameter ${1}"
		 printUsage
		 exit
	 fi
         fi
         fi
	 shift 2
 done


if [[ "$TARGET" = "" ]];
  then TARGET=".*"
fi

if [[ "$CONFIGFILE" = "" ]];
  then CONFIGFILE="distributions.config"
fi

if [[ "$MAXPARALLEL" = "" ]];
  then MAXPARALLEL=4
fi

echo Building with configfile $CONFIGFILE   target $TARGET   maxparallel $MAXPARALLEL

# Build all the version-specific SQL files
for line in $(grep -v '#' $CONFIGFILE | grep -v "^$" | grep "$TARGET" )
do
  make_target "${line}"

# Wait a couple of seconds before starting another collection.
 sleep 2
 
 # Do not run another collection if there are too many running already
 while [[ $(ps -ef | grep mkall.sh | grep -v grep | wc -l) -ge ${MAXPARALLEL} ]]
 do
  echo sleeping for 10 secs while waiting on collections:
  ps | grep mkall.sh | grep -v grep | cut -d '@' -f 2 | cut -d ' ' -f 1

  sleep 10
 done
done 
echo Done
 
