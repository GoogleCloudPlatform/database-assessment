     #!/bin/bash
     # /***************************************
     # * Copyright (c) 2023 Oracle and/or its affiliates.
     # * Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
     # ***************************************
     # * OEE Group Extract Standalone v5.1
     # ****************************************/

     #!/bin/bash

     get_extract_type() {
     while true; do
          read -p "Please enter a number (1 or 2): " extractType
          case $extractType in
               1|2)
                    break
                    ;;
               *)
                    echo "Invalid input. Please enter 1 or 2."
                    ;;
          esac
     done
     }

     get_cpat_home() {
	read -p "Please enter your CPAT_HOME: " CPAT_HOME_var
     }

     runTimestamp=$(printf "$(date +'%y%m%d_%H%M%S')")
     logFile=$1"_"$runTimestamp".log"
     failureFile=$1"_"$runTimestamp".failures"
     (
     printf "\n"
     printf "****************************************************\n"
     printf "Oracle Estate Explorer v5.0 StandAlone Group Extract\n"
     printf "****************************************************\n"
     printf "\n"

     printf "\n"
     echo "What extraction method would you like to use?"
     echo "1 - CPAT"
     echo "2 - SQLPlus"
     printf "\n"
     get_extract_type

     if [[ $extractType == "1" ]]
     then
     	get_cpat_home
	export CPAT_HOME=$CPAT_HOME_var
     fi

     # Set Variables
     extractSQLScript="oee_group_dbextract-SA.sql"
     metricsSQLScript="oee_group_metrics-SA.sql"
     extractDate=`date +"%0d-%^b-%y %0H:%0M:%0S"`
     driverFile="$1"
     toProcess=$(wc -l "$driverFile"|awk '{print $1}')-1
     let toProcess=toProcess+1
     databaseCounter=0
     databaseFailures=0
     databaseSuccesses=0
     metricsFailures=0
     metricsSuccesses=0
     groupLabel=$(echo $driverFile|awk '{split($0,a,"_"); print a[2]}'|awk '{split($0,b,"."); print b[1]}')
     filesToZip=()

     if [ -f "oee_temp$groupLabel.txt" ]; then
          rm -f oee_temp$groupLabel.txt
     fi

     # If a zip archive file already exists for this group, delete it
    if [ -f $groupLabel.zip ]; then
        echo "file: $groupLabel.zip exists."
        echo "Deleting...."
        rm -f $groupLabel.zip
        printf "Done.\n"
    fi

     printf "Extracting $toProcess databases for this Group\n"
     printf "\n"

     # Begin processing databases within the DriverFile
     while read -r line || [[ -n "$line" ]]; do

          # Timestamp
          let databaseCounter=databaseCounter+1

          # Extract the groupID, guid and driver details from the record in the DriverFile
          guid=$(echo $line|awk '{split($0,a,":"); print a[1]}')

          if [[ $extractType == "1" ]] 
	     then
               extractOutputFile="$guid.json"
          else
               extractOutputFile="$guid.txt"
          fi

          # If an output file already exists for this group, rename it
          if [ -f $extractOutputFile ]; then
               echo "file: $extractOutputFile exists."
               echo "Renaming to $extractOutputFile.old"
               mv -f $extractOutputFile $extractOutputFile.old
               printf "\n"
          fi

          if [[ $extractType == "2" ]] 
	     then
               echo "RECORD_TYPE|DB_TARGET_GUID|DBID|EXTRACT_TIMESTAMP|ACTION_ID|JSON_PAYLOAD">$extractOutputFile
          fi
     
          database=$(echo $line|awk '{split($0,a,":"); print a[2]}')
          if [[ $line == *"://"* ]]
          then tnsString=$(echo $line|awk -F '://' '{split($2, arr, "/"); split(arr[2], subarr, ":"); print "//" arr[1] "/" subarr[1]}')
               if [[ $tnsString == *":"* ]]
               then
                    connectMessage="Using Easy Connect with specified port - $tnsString"
                    dbUser=$(echo $line|awk '{split($0,a,":"); print a[5]}')
                    password=$(echo $line|awk '{split($0,a,":"); print a[6]}')
               else
                    connectMessage="Using Easy Connect with implied port - $tnsString"
                    dbUser=$(echo $line|awk '{split($0,a,":"); print a[4]}')
                    password=$(echo $line|awk '{split($0,a,":"); print a[5]}')
               fi
          else tnsString=$(echo $line|awk '{split($0,a,":"); print a[3]}')
               connectMessage="Using TNS entry - $tnsString"
               dbUser=$(echo $line|awk '{split($0,a,":"); print a[4]}')
               password=$(echo $line|awk '{split($0,a,":"); print a[5]}')
          fi
          
          tnsNoSpaces="${tnsString// /}"
          tnsString=$tnsNoSpaces
     
          printf "\n"
          printf "_______________________________________________________________\n"
          printf '%(%F %T)T '
          printf "OEE processing target ($databaseCounter/$toProcess):$database\n"
          printf "$connectMessage\n"
     
          sqlplus $dbUser/$password@$tnsString <<EOF > status.txt
     set echo off
     select 'REACHABLE' as STATUS from dual;
EOF
          reachable=$(cat status.txt|grep REACHABLE|wc -l) 

          if [[ $reachable == "1" ]]
          then printf "Database Reachable\n"
               printf "\n"

                              if [[ $extractType == "1" ]] 
	       then

                     tnsStringNoQuotes=${tnsString//\"/}
                     #printf "$tnsStringNoQuotes"

                     cpatString="'jdbc:oracle:thin:@${tnsStringNoQuotes}'"
		           #printf "Connect to: $cpatString\n"

                     cmd="sh $CPAT_HOME/premigration.sh -o . -c $cpatString -K $guid --targetcloud ALL --migrationmethod ALL -u DBSNMP --reportformat json --outfileprefix "DB_"$guid --maxsubprocesses 6 --gatherdetails OEE_FULL  <<< $password"
		     eval "$cmd"

		     if [[ -f "DB_"$guid"_premigration_advisor_report.json" ]] 
		     then
		     	let databaseSuccesses=databaseSuccesses+1
                     	mv "DB_"$guid"_premigration_advisor_report.json" $extractOutputFile
			files_to_zip+=("$extractOutputFile")

			metricsOutputFile=$guid"_metrics.txt"
                        cat  "DB_"$guid"_mpack_metrics.csv"| awk '/^MPACK_/{print}' | awk -v theguid=$guid '{sub("GUIDPLACEHOLDER",theguid, $0); print}' >$metricsOutputFile
                        rm -rf "DB_"$guid"_mpack_metrics.csv"
			files_to_zip+=("$metricsOutputFile")

		     else
			if [[ -f "DB_"$guid"_premigration_advisor_summary_report.json" ]] 
                     	then
			    printf "IS CDB\n"
                            open_pdbs=$(grep -o '"openPDBs":[^]]*]'  "DB_"$guid"_premigration_advisor_summary_report.json" | sed -E 's/.*\[//; s/\]//; s/"//g')
                            IFS=',' read -ra pdb_array <<< "$open_pdbs"

                            for pdb in "${pdb_array[@]}"; do
				#printf "$pdb\n"    
				#let databaseSuccesses=databaseSuccesses+1
                                #mv "$pdb"/$pdb"_DB_"$guid"_premigration_advisor_report.json" $pdb"_"$extractOutputFile
				#files_to_zip+=("$pdb"_"$extractOutputFile")
				
				#metricsOutputFile=$pdb"_"$guid"_metrics.txt"
				#cat "$pdb"/$pdb"_DB_"$guid"_mpack_metrics.csv"| awk '/^MPACK_/{print}' | awk -v theguid=$guid '{sub("GUIDPLACEHOLDER",theguid, $0); print}' >$metricsOutputFile
				#files_to_zip+=("$metricsOutputFile")
				rm -rf $pdb
                            done
			else	
                           let databaseFailures=databaseFailures+1
			fi
	             fi
		      
               else

               if [[ $extractType == "2" ]]
               then printf "Executing Database Extract"
                    sqlplus $dbUser/$password@$tnsString <<EOF >oee_temp.txt
                    @$extractSQLScript
EOF
                    oraerrors=$(cat oee_temp.txt|grep "ORA-"|wc -l)
                    plserrors=$(cat oee_temp.txt|grep "PLS-"|wc -l)
                    success=$(cat oee_temp.txt|grep "MPACK_DATABASE"|wc -l)

                    if [[ $oraerrors != "0" ]]
                    then printf "\nFAILURE : ORACLE ERROR\n"
                         let databaseFailures=databaseFailures+1
                         failureError=$(cat oee_temp.txt|grep ORA-)
                         printf "$failureError\n"
                         echo $line " | DBExtract Error - " $failureError >> $failureFile	
                    else if [[ $plserrors != "0" ]]
                         then printf "\nFAILURE : PL/SQL ERROR\n"
                              let databaseFailures=databaseFailures+1
                              failureError=$(cat oee_temp.txt|grep PLS-)
                              printf "$failureError\n"
                              echo $line " | DBExtract Error - " $failureError >> $failureFile	
                         else if [[ $success == "1" ]]
                              then printf "....Completed\n"
                                   printf "extract SUCCESSFUL "
                                   let databaseSuccesses=databaseSuccesses+1
                                   actualSize=$(wc -c <oee_temp.txt)
                                   printf "($actualSize bytes of data retrieved from target)\n"

                                   # Parse temp output file and stream to main output file
                                   cat oee_temp.txt| awk '/^MPACK_/{print}' | awk -v theguid=$guid '{sub("GUIDPLACEHOLDER",theguid, $0); print}' >oee_temp2.txt
                                   cat oee_temp2.txt >>$extractOutputFile

                              else printf "extract FAILED\n"
                                   let databaseFailures=databaseFailures+1
                                   echo $line " | DBExtract Error - Unknown Extract Script Error. No MPACK_DATABASE Record Created">> $failureFile
                              fi
                         fi
                    fi
                    fi
                    if [[ $extractType == "2" ]]
                    then printf "Executing Metrics Extract" 
                         sqlplus $dbUser/$password@$tnsString <<EOF >oee_temp.txt
                         @$metricsSQLScript
EOF
                         oraerrors=$(cat oee_temp.txt|grep "ORA-"|wc -l)
                         plserrors=$(cat oee_temp.txt|grep "PLS-"|wc -l)
                         success=$(cat oee_temp.txt|grep "MPACK_DBINFO"|wc -l)

                         if [[ $oraerrors != "0" ]]
                         then printf "\nFAILURE : ORACLE ERROR\n"
                              let metricsFailures=metricsFailures+1
                              failureError=$(cat oee_temp.txt|grep ORA-)
                              printf "$failureError\n"
                              echo $line " | Metrics Error - " $failureError >> $failureFile	
                         else if [[ $plserrors != "0" ]]
                              then printf "\nFAILURE : PL/SQL ERROR\n"
                                   let metricsFailures=metricsFailures+1
                                   failureError=$(cat oee_temp.txt|grep PLS-)
                                   printf "$failureError\n"
                                   echo $line " | Metrics Error - " $failureError >> $failureFile	
                              else if [[ $success == "1" ]]
                                   then printf "....Completed\n"
                                        printf "extract SUCCESSFUL "
                                        let metricsSuccesses=metricsSuccesses+1
                                        actualSize=$(wc -c <oee_temp.txt)
                                        printf "($actualSize bytes of data retrieved from target)\n"

                                        # Parse temp output file and stream to main output file
                                        cat oee_temp.txt| awk '/^MPACK_/{print}' | awk -v theguid=$guid '{sub("GUIDPLACEHOLDER",theguid, $0); print}' >oee_temp2.txt
                                        cat oee_temp2.txt >>$extractOutputFile
                                   else printf "extract FAILED\n"
                                        let metricsFailures=metricsFailures+1
                                        echo $line " | Metrics Error - Unknown Extract Script Error. No MPACK_DBINFO Record Created">> $failureFile
                                   fi
                              fi
                         fi
                    fi
                    files_to_zip+=("$extractOutputFile")
               fi
               else printf "\nFAILURE : TARGET UNREACHABLE\n"
               let databaseFailures=databaseFailures+1
               let metricsFailures=metricsFailures+1
               failureError=$(cat status.txt|grep ORA-)
               printf "$failureError\n"
               echo $line " | " $failureError >> $failureFile
          fi

          done < "$driverFile"
     # The DriverFile has now been fully processed

     printf "\n"
     printf "Creating OEE Zip Archive\n"
     printf "************************\n"
     zip $groupLabel.zip "${files_to_zip[@]}"
     rm "${files_to_zip[@]}"
     dbextractOutputSize=$(wc -c <$groupLabel.zip)

     # Display Summary
     printf "\n"
     printf '%(%F %T)T '
     printf "\n"
     printf "************************************************\n"
     printf "OEE v5.0 Group Extract Summary - Standalone\n"
     printf "************************************************\n"
     printf "\n"
     printf "Driverfile processed\n"
     printf "Group Extracted\n"
     printf "\n"
     printf "Database extract successes : $databaseSuccesses\n"
     printf "Database extract failures  : $databaseFailures\n" 
     printf "Database Extracts can be found in $groupLabel.zip  ($dbextractOutputSize bytes)\n"
	printf "\n"
     printf "Logging can be found in $logFile\n"
     printf "Failures can be found in $failureFile\n"
     printf "\n"

     rm oee_temp.txt oee_temp2.txt status.txt 2>/dev/null
     ) 2>&1 | tee $logFile