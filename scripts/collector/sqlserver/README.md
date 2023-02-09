# sqlsrvscripts
You can run all the powershell commands using the bat file - RunAssessment.bat. Output will be in the output folder

Following are the instructions if you want to run each Powershell file for testing:

InstanceReview.ps1 calls sql scripts to assess instance level configuration. Multiple ways to run this powershell script. One way is to run it from cmd line. In cmd prompt first cd to the path where these sql scripts are downloaded and then run following cmd in the cmd prompt:

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\InstanceReview.ps1'"
 
DBAssess.ps1 calls sql scripts to assess database level features. Multiple ways to run this powershell script. One way is to run it from cmd line. In cmd prompt first cd to the path where these sql scripts are downloaded and then run following cmd in the cmd prompt:

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\DBAssess.ps1'"

SizingAssess.ps1 contains sql scripts to assess sizing of CPU, memory and IO. Multiple ways to run this powershell script. One way is to run it from cmd line. In cmd prompt first cd to the path where these sql scripts are downloaded and then run following cmd in the cmd prompt:

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\SizingAssess.ps1'"
