# sql2sqlassessment

# Prerequisites
1. sqlsrv.csv contains instancename and port
Add all the instance names and port numbers you would like the assessment to be run on.

2. prereq_createsa.sql creates the user which is used for running these scripts. This script needs to be run on each SQL Server instance.
If you want to create the user in automated way you can use createuserwithwindowsauth.ps1 (to connect using windows auth) or createuserwithsqluser.ps1 (to connect using sql auth, you need to pass user and password to the script as shown below:
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\createuserwithsqluser.ps1 -user sql1 -pwd P@ssword1'")

# Steps
You can run all the powershell commands using the bat file - RunAssessment.bat. Output will be in the folder where RunAssessment.bat is placed

Following are the instructions if you want to run each Powershell file for testing:

InstanceReview.ps1 calls sql scripts to assess instance level configuration. Multiple ways to run this powershell script. One way is to run it from cmd line. In cmd prompt first cd to the path where these sql scripts are downloaded and then run following cmd in the cmd prompt:

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\InstanceReview.ps1'"