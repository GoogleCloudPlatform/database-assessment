# Copyright 2023 Google LLC
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
<#
.SYNOPSIS
    .
.DESCRIPTION
    Creates a perfmon dataset and subsequent data files to be uploaded to Google Database Migration Assistant for MS SQL Server.
.PARAMETER operation
    Enter one of create,stop,delete,collect (Mandatory)
		create - creates the perfmon dataset and starts the collection.  The collection will stop automatically after 8 days
		stop - stops the collection
		delete - deletes the collection and leaves any data set collection files present int eh appropriate location
		collect - moves the dataset collection to the downloads directory and creates a tar of the results
.PARAMETER namedInstanceName
    Enter the named instance name (Optional, unless using a named instance)
	If collecting from a named instance, enter the instance name or the default instance will be used.
.PARAMETER perfmonOutDir
    Final Output Directory (Required)
.PARAMETER perfmonOutFile
    Final Output File Name (Required)
.PARAMETER dmaSourceId
    DMA derived unique id (Required)
.PARAMETER dmaManualId
    Customer Manual Unique ID or dma manual unique id (Optional)
.EXAMPLE
    C:\dmaSQLServerPerfmonDataset.ps1 -operation create -namedInstanceName [named Instance] / $null
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
param (
	[Parameter(
		Mandatory=$True,
		HelpMessage="Enter one of create,stop,delete,collect"
	)][string]$operation,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The instance name if a named instance is used"
	)][string]$namedInstanceName=$null,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The dir name for the final perfmon combined file"
	)][string]$perfmonOutDir=$null,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The file name for the final perfmon combined file"
	)][string]$perfmonOutFile=$null,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The pkey value for the final perfmon combined file"
	)][string]$pkey=$null,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The dma_source_id value for the final perfmon combined file"
	)][string]$dmaSourceId,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The dma_manual_id / customer supplied tag value for the final perfmon combined file"
	)][string]$dmaManualId="NA",
	[Parameter(
		Mandatory=$False,
		HelpMessage="The number of intervals that perfmon sample will run defaults to 1152 (10 minute samples for 8 days)"
	)][string]$perfmonDuration="1152",
	[Parameter(
		Mandatory=$False,
		HelpMessage="The interval that perfmon sample will run defaults to 600 (every 10 minutes)"
	)][string]$perfmonSampleInterval="600"
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

if (!$machinename) {
	$machinename = hostname
}

if (!$current_ts) {
	$current_ts = Get-Date -Format "MMddyyyyTHHmmss"
}

if ($namedInstanceName) {
	$perfmonLogFile = 'opdb__perfMonLog' + '__' + $operation + '_' + $machinename + '_' + $namedInstanceName + '_' + $current_ts + '.log'
	if (!$perfmonOutFile) {
		$perfmonOutFile = 'opdb__PerfMonData' + '_' + $machinename + '_' + $namedInstanceName + '_' + $current_ts + '.csv'
	 }
} else {
	$perfmonLogFile = 'opdb__perfMonLog' + '__' + $operation + '_' + $machinename + '_MSSQLSERVER_' + $current_ts + '.log'
	if (!$perfmonOutFile) {
	    $perfmonOutFile = 'opdb__PerfMonData' + '_' + $machinename + '_MSSQLSERVER_' + $current_ts + '.csv'
    }
}

function CreateDMAPerfmonDataSet
{
param(
    [string]$instanceName,
	[string]$dataSet,
	[string]$perfmonOutDir,
	[string]$logFile,
	[string]$perfmonDuration,
	[string]$perfmonSampleInterval
    )
if ((!$perfmonDuration) -or (!$perfmonSampleInterval)) {
	$perfmonDuration=1152
	$perfmonSampleInterval=600
}

$perfmonDuration = [int]$perfmonDuration
$perfmonSampleInterval = [int]$perfmonSampleInterval
$perfmonTotalDuration=[int]$perfmonDuration * [int]$perfmonSampleInterval

if ($instanceName) {
$str = @'
<DataCollectorSet>
	<Status>1</Status>
	<Duration>$perfmonTotalDuration</Duration>
	<Description>
	</Description>
	<DescriptionUnresolved>
	</DescriptionUnresolved>
	<DisplayName>
	</DisplayName>
	<DisplayNameUnresolved>
	</DisplayNameUnresolved>
	<SchedulesEnabled>-1</SchedulesEnabled>
	<LatestOutputLocation>C:\PerfLogs\Admin\Google-DMA-SQLServerDataSet\</LatestOutputLocation>
	<Name>$dataset</Name>
	<OutputLocation>C:\PerfLogs\Admin\Google-DMA-SQLServerDataSet\</OutputLocation>
	<RootPath>%systemdrive%\PerfLogs\Admin\Google-DMA-SQLServerDataSet</RootPath>
	<Segment>0</Segment>
	<SegmentMaxDuration>0</SegmentMaxDuration>
	<SegmentMaxSize>0</SegmentMaxSize>
	<SerialNumber>5</SerialNumber>
	<Server>
	</Server>
	<Subdirectory>
	</Subdirectory>
	<SubdirectoryFormat>1</SubdirectoryFormat>
	<SubdirectoryFormatPattern>
	</SubdirectoryFormatPattern>
	<Task>
	</Task>
	<TaskRunAsSelf>0</TaskRunAsSelf>
	<TaskArguments>
	</TaskArguments>
	<TaskUserTextArguments>
	</TaskUserTextArguments>
	<UserAccount>SYSTEM</UserAccount>
	<Security>O:BAG:S-1-5-21-3404621412-1649883821-2893091589-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;0x1200a9;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077-2999183737-3043590567-590698655)(A;ID;0x1f019f;;;BA)(A;ID;0x1f019f;;;SY)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)(A;ID;FA;;;BA)</Security>
	<StopOnCompletion>1</StopOnCompletion>
	<PerformanceCounterDataCollector>
		<DataCollectorType>0</DataCollectorType>
		<Name>System Monitor Log</Name>
		<FileName>$dataset</FileName>
		<FileNameFormat>3</FileNameFormat>
		<FileNameFormatPattern>NddMMyyyy</FileNameFormatPattern>
		<LogAppend>0</LogAppend>
		<LogCircular>0</LogCircular>
		<LogOverwrite>0</LogOverwrite>
		<LatestOutputLocation></LatestOutputLocation>
		<DataSourceName>
		</DataSourceName>
		<SampleInterval>$perfmonSampleInterval</SampleInterval>
		<SegmentMaxRecords>$perfmonDuration</SegmentMaxRecords>
		<LogFileFormat>0</LogFileFormat>
		<Counter>\Memory\Available MBytes</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk Bytes/Read</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk Bytes/Write</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk sec/Read</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk sec/Write</Counter>
		<Counter>\PhysicalDisk(_Total)\Disk Reads/sec</Counter>
		<Counter>\PhysicalDisk(_Total)\Disk Writes/sec</Counter>
		<Counter>\Processor(_Total)\% Idle Time</Counter>
		<Counter>\Processor(_Total)\% Processor Time</Counter>
		<Counter>\Processor Information(_Total)\Processor Frequency</Counter>
		<Counter>\System\Processor Queue Length</Counter>
		<Counter>\$instance:Databases(_Total)\Log Truncations</Counter>
		<Counter>\$instance:Buffer Manager\Buffer cache hit ratio</Counter>
		<Counter>\$instance:Buffer Manager\Checkpoint pages/sec</Counter>
		<Counter>\$instance:Buffer Manager\Page life expectancy</Counter>
		<Counter>\$instance:Buffer Manager\Page reads/sec</Counter>
		<Counter>\$instance:Buffer Manager\Page writes/sec</Counter>
		<Counter>\$instance:Buffer Manager\Page lookups/sec</Counter>
		<Counter>\$instance:Buffer Manager\Free list stalls/sec</Counter>
		<Counter>\$instance:Memory Manager\Memory Grants Pending</Counter>
		<Counter>\$instance:Memory Manager\Target Server Memory (KB)</Counter>
		<Counter>\$instance:Memory Manager\Total Server Memory (KB)</Counter>
		<Counter>\$instance:SQL Statistics\Batch Requests/sec</Counter>
		<Counter>\NUMA Node Memory(_Total)\Total MBytes</Counter>
		<Counter>\NUMA Node Memory(_Total)\Available MBytes</Counter>
		<CounterDisplayName>\Memory\Available MBytes</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk Bytes/Read</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk Bytes/Write</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk sec/Read</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk sec/Write</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Disk Reads/sec</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Disk Writes/sec</CounterDisplayName>
		<CounterDisplayName>\Processor(_Total)\% Idle Time</CounterDisplayName>
		<CounterDisplayName>\Processor(_Total)\% Processor Time</CounterDisplayName>
		<CounterDisplayName>\Processor Information(_Total)\Processor Frequency</CounterDisplayName>
		<CounterDisplayName>\System\Processor Queue Length</CounterDisplayName>
		<CounterDisplayName>\$instance:Databases(_Total)\Log Truncations</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Buffer cache hit ratio</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Checkpoint pages/sec</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Page life expectancy</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Page reads/sec</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Page writes/sec</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Page lookups/sec</CounterDisplayName>
		<CounterDisplayName>\$instance:Buffer Manager\Free list stalls/sec</CounterDisplayName>
		<CounterDisplayName>\$instance:Memory Manager\Memory Grants Pending</CounterDisplayName>
		<CounterDisplayName>\$instance:Memory Manager\Target Server Memory (KB)</CounterDisplayName>
		<CounterDisplayName>\$instance:Memory Manager\Total Server Memory (KB)</CounterDisplayName>
		<CounterDisplayName>\$instance:SQL Statistics\Batch Requests/sec</CounterDisplayName>
		<CounterDisplayName>\NUMA Node Memory(_Total)\Total MBytes</CounterDisplayName>
		<CounterDisplayName>\NUMA Node Memory(_Total)\Available MBytes</CounterDisplayName>
	</PerformanceCounterDataCollector>
	<DataManager>
		<Enabled>0</Enabled>
		<CheckBeforeRunning>0</CheckBeforeRunning>
		<MinFreeDisk>0</MinFreeDisk>
		<MaxSize>0</MaxSize>
		<MaxFolderCount>0</MaxFolderCount>
		<ResourcePolicy>0</ResourcePolicy>
		<ReportFileName>report.html</ReportFileName>
		<RuleTargetFileName>report.xml</RuleTargetFileName>
		<EventsFileName>
		</EventsFileName>
	</DataManager>
</DataCollectorSet>
'@
} else {
$str = @'
	<DataCollectorSet>
	<Status>1</Status>
	<Duration>$perfmonTotalDuration</Duration>
	<Description>
	</Description>
	<DescriptionUnresolved>
	</DescriptionUnresolved>
	<DisplayName>
	</DisplayName>
	<DisplayNameUnresolved>
	</DisplayNameUnresolved>
	<SchedulesEnabled>-1</SchedulesEnabled>
	<LatestOutputLocation>C:\PerfLogs\Admin\Google-DMA-SQLServerDataSet\</LatestOutputLocation>
	<Name>$dataset</Name>
	<OutputLocation>C:\PerfLogs\Admin\Google-DMA-SQLServerDataSet\</OutputLocation>
	<RootPath>%systemdrive%\PerfLogs\Admin\Google-DMA-SQLServerDataSet</RootPath>
	<Segment>0</Segment>
	<SegmentMaxDuration>0</SegmentMaxDuration>
	<SegmentMaxSize>0</SegmentMaxSize>
	<SerialNumber>5</SerialNumber>
	<Server>
	</Server>
	<Subdirectory>
	</Subdirectory>
	<SubdirectoryFormat>1</SubdirectoryFormat>
	<SubdirectoryFormatPattern>
	</SubdirectoryFormatPattern>
	<Task>
	</Task>
	<TaskRunAsSelf>0</TaskRunAsSelf>
	<TaskArguments>
	</TaskArguments>
	<TaskUserTextArguments>
	</TaskUserTextArguments>
	<UserAccount>SYSTEM</UserAccount>
	<Security>O:BAG:S-1-5-21-3404621412-1649883821-2893091589-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;0x1200a9;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077-2999183737-3043590567-590698655)(A;ID;0x1f019f;;;BA)(A;ID;0x1f019f;;;SY)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)(A;ID;FA;;;BA)</Security>
	<StopOnCompletion>1</StopOnCompletion>
	<PerformanceCounterDataCollector>
		<DataCollectorType>0</DataCollectorType>
		<Name>System Monitor Log</Name>
		<FileName>$dataset</FileName>
		<FileNameFormat>3</FileNameFormat>
		<FileNameFormatPattern>NddMMyyyy</FileNameFormatPattern>
		<LogAppend>0</LogAppend>
		<LogCircular>0</LogCircular>
		<LogOverwrite>0</LogOverwrite>
		<LatestOutputLocation></LatestOutputLocation>
		<DataSourceName>
		</DataSourceName>
		<SampleInterval>$perfmonSampleInterval</SampleInterval>
		<SegmentMaxRecords>$perfmonDuration</SegmentMaxRecords>
		<LogFileFormat>0</LogFileFormat>
		<Counter>\Memory\Available MBytes</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk Bytes/Read</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk Bytes/Write</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk sec/Read</Counter>
		<Counter>\PhysicalDisk(_Total)\Avg. Disk sec/Write</Counter>
		<Counter>\PhysicalDisk(_Total)\Disk Reads/sec</Counter>
		<Counter>\PhysicalDisk(_Total)\Disk Writes/sec</Counter>
		<Counter>\Processor(_Total)\% Idle Time</Counter>
		<Counter>\Processor(_Total)\% Processor Time</Counter>
		<Counter>\Processor Information(_Total)\Processor Frequency</Counter>
		<Counter>\System\Processor Queue Length</Counter>
		<Counter>\SQLServer:Buffer Manager\Buffer cache hit ratio</Counter>
		<Counter>\SQLServer:Buffer Manager\Checkpoint pages/sec</Counter>
		<Counter>\SQLServer:Buffer Manager\Free list stalls/sec</Counter>
		<Counter>\SQLServer:Buffer Manager\Page life expectancy</Counter>
		<Counter>\SQLServer:Buffer Manager\Page lookups/sec</Counter>
		<Counter>\SQLServer:Buffer Manager\Page reads/sec</Counter>
		<Counter>\SQLServer:Buffer Manager\Page writes/sec</Counter>
		<Counter>\SQLServer:General Statistics\User Connections</Counter>
		<Counter>\SQLServer:Memory Manager\Memory Grants Pending</Counter>
		<Counter>\SQLServer:Memory Manager\Target Server Memory (KB)</Counter>
		<Counter>\SQLServer:Memory Manager\Total Server Memory (KB)</Counter>
		<Counter>\SQLServer:SQL Statistics\Batch Requests/sec</Counter>
		<Counter>\NUMA Node Memory(_Total)\Total MBytes</Counter>
		<Counter>\NUMA Node Memory(_Total)\Available MBytes</Counter>
		<CounterDisplayName>\Memory\Available MBytes</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk Bytes/Read</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk Bytes/Write</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk sec/Read</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Avg. Disk sec/Write</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Disk Reads/sec</CounterDisplayName>
		<CounterDisplayName>\PhysicalDisk(_Total)\Disk Writes/sec</CounterDisplayName>
		<CounterDisplayName>\Processor(_Total)\% Idle Time</CounterDisplayName>
		<CounterDisplayName>\Processor(_Total)\% Processor Time</CounterDisplayName>
		<CounterDisplayName>\Processor Information(_Total)\Processor Frequency</CounterDisplayName>
		<CounterDisplayName>\System\Processor Queue Length</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Buffer cache hit ratio</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Checkpoint pages/sec</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Free list stalls/sec</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Page life expectancy</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Page lookups/sec</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Page reads/sec</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Buffer Manager\Page writes/sec</CounterDisplayName>
		<CounterDisplayName>\SQLServer:General Statistics\User Connections</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Memory Manager\Memory Grants Pending</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Memory Manager\Target Server Memory (KB)</CounterDisplayName>
		<CounterDisplayName>\SQLServer:Memory Manager\Total Server Memory (KB)</CounterDisplayName>
		<CounterDisplayName>\SQLServer:SQL Statistics\Batch Requests/sec</CounterDisplayName>
		<CounterDisplayName>\NUMA Node Memory(_Total)\Total MBytes</CounterDisplayName>
		<CounterDisplayName>\NUMA Node Memory(_Total)\Available MBytes</CounterDisplayName>
	</PerformanceCounterDataCollector>
	<DataManager>
		<Enabled>0</Enabled>
		<CheckBeforeRunning>0</CheckBeforeRunning>
		<MinFreeDisk>0</MinFreeDisk>
		<MaxSize>0</MaxSize>
		<MaxFolderCount>0</MaxFolderCount>
		<ResourcePolicy>0</ResourcePolicy>
		<ReportFileName>report.html</ReportFileName>
		<RuleTargetFileName>report.xml</RuleTargetFileName>
		<EventsFileName>
		</EventsFileName>
	</DataManager>
</DataCollectorSet>
'@
}

	$xmlTempDir = $env:TEMP
	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir
	$metricInstanceName = "MSSQL`$" + $instanceName
	$perfmonDataSetExists = logman.exe query -n $dataSet
	if ($perfmonDataSetExists -Like "*Data Collector Set was not found*") {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Beginning Creation of the Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
		if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Removing old perfmon data files..." -logOperation "BOTH"
			Remove-Item -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv
		}
		if (Test-Path -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Removing old perfmon template file..." -logOperation "BOTH"
			Remove-Item -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml
		}
	} else {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Google DMA SQL Server Perfmon Counter Data Set found..." -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Stopping Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
		logman.exe stop -n $dataSet
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Deleting Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
		logman.exe delete -n $dataSet
		if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Removing old perfmon data files..." -logOperation "BOTH"
			Remove-Item -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv
		}
		if (Test-Path -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Removing old perfmon template file..." -logOperation "BOTH"
			Remove-Item -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml
		}
	}


	$newXML = $str.Replace('$instance', $metricInstanceName).Replace('$dataset', $dataSet)
	$newXML = $newXML.Replace('$perfmonDuration', $perfmonDuration).Replace('$perfmonSampleInterval', $perfmonSampleInterval)
	$newXML = $newXML.Replace('$perfmonTotalDuration', $perfmonTotalDuration)

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Writing XML File to be used for import to perfmon..." -logOperation "BOTH"
	$newXML | Out-File -FilePath $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml -encoding utf8

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Importing Google DMA SQL Server Perfmon Counter Data Set from Template..." -logOperation "BOTH"
	logman.exe import -n $dataSet -xml (Get-ChildItem -Path $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml | ForEach-Object { $_.FullName })

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Starting Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
	logman.exe start -n $dataSet
	logman.exe query -n $dataset | out-string | Add-Content -Encoding utf8 -Path $outputDir\$perfmonLogFile
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Operation Completed..." -logOperation "BOTH"

	$debug_flag = $null

	if ($debug_flag) {
		Write-Output "Perfmon number of sample intervals: " $perfmonDuration
		Write-Output "Perfmon seconds between sample intervals: " $perfmonSampleInterval
		Write-Output "Total Duration of Perfmon Collection " $perfmonTotalDuration
		Write-Output "Display template being used for import: "
		Write-Output $newXML
		Write-Output "XML Output Directory: $xmlTempDir"
		Write-Output "Passed in Instance Name: $instanceName"
		Write-Output "Derived in Metric Instance Name: $metricInstanceName"
		Write-Output "Directory Listing of $xmlTempDir"
		Write-Output "Dataset Name is: $dataSet"
			Get-ChildItem -Path $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml
		Write-Output "Directory Listing of $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet"
			Get-ChildItem -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv
	}
}

function StartDMAPerfmonDataSet
{
param(
    [string]$dataSet,
	[string]$perfmonOutDir,
	[string]$logFile
    )

	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Starting Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
	logman.exe start -n $dataSet
	logman.exe query -n $dataset | out-string | Add-Content -Encoding utf8 -Path $outputDir\$perfmonLogFile
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Operation Completed..." -logOperation "BOTH"
}
function StopDMAPerfmonDataSet
{
param(
    [string]$dataSet,
	[string]$perfmonOutDir,
	[string]$logFile
    )

	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Stopping Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
	logman.exe stop -n $dataSet
	logman.exe query -n $dataset | out-string | Add-Content -Encoding utf8 -Path $outputDir\$perfmonLogFile
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Operation Completed..." -logOperation "BOTH"
}
function DeleteDMAPerfmonDataSet
{
param(
	[string]$dataSet,
	[string]$perfmonOutDir,
	[string]$logFile
	)
	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir
	$perfmonDataSetRunning = logman.exe query -n $dataSet

	if ($perfmonDataSetRunning -like "*Status:               Running*") {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Google DMA SQL Server Perfmon Counter Data Set is running... Stopping Data Collector Set before deletion..." -logOperation "BOTH"
		logman.exe stop -n $dataSet
		logman.exe delete -n $dataSet
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Operation Completed..." -logOperation "BOTH"
	} else {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Google DMA SQL Server Perfmon Counter Data Set found, but not running..... Deleting..." -logOperation "BOTH"
		logman.exe delete -n $dataSet
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Operation Completed..." -logOperation "BOTH"
	}
}
function Yellow{    process { Write-Host $_ -ForegroundColor Yellow }}

function StatusDMAPerfmonDataSet
{
param(
    [string]$dataSet,
	[string]$perfmonOutDir,
	[string]$perfmonLogFile,
	[string]$logFile
    )

	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir
	$maxFileDate = $null
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Checking the status of the Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
	$perfmonDataSetRunning = logman.exe query -n $dataSet
	if ($perfmonDataSetRunning -like "*Status:               Running*") {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " Perfmon counter 'Running'" -logOperation "BOTH"
	} else {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " Perfmon counter 'Stopped'" -logOperation "BOTH"
	}

	if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv) {
		foreach($file in Get-ChildItem -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataset*.csv)
		{
			$currentFileDate = (Get-Item $file).LastWriteTime
			if ($currentFileDate -ge $maxFileDate) {
				$maxFileDate = $currentFileDate
			}
		}
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " Max perfmon file date available: $maxFileDate" -logOperation "BOTH"
	}
}
function CollectDMAPerfmonDataSet
{
param(
	[string]$dataSet,
	[string]$perfmonOutDir,
	[string]$perfmonOutFile,
	[string]$pkey,
	[string]$logFile,
	[string]$dmaSourceId,
	[string]$dmaManualId
	)

	$outputDir = $PSScriptRoot + "\" + $perfmonOutDir
	$outputFileName = $perfmonOutFile
	$maxFileDate = $null

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Collecting results from the Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"

	if (!(Test-Path -PathType container $outputDir)) {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Creating Output Directory $outputDir..." -logOperation "BOTH"
		$null = New-Item -ItemType Directory -Path $outputDir
	}

	if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataSet*.csv) {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		$fileExists = $true
		foreach($file in Get-ChildItem -Path $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet\*$dataset*.csv)
		{
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Moving perfmon datafile: $file to the $env:TEMP directory without header" -logOperation "BOTH"
			$tempFileName = Split-Path $file -leaf
			Get-Content -Path $file | Select-Object -Skip 1 | Set-Content -Encoding utf8 -Path $env:TEMP\$tempFileName
			$currentFileDate = (Get-Item $file).LastWriteTime
			if ($currentFileDate -ge $maxFileDate) {
				$maxFileDate = $currentFileDate
			}
		}
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Adding additional fields to perfmon files without header" -logOperation "BOTH"
		foreach($file in Get-ChildItem -Path $env:TEMP\*$dataSet*.csv) {
			$tempFileName = 'PKEY_' + (Split-Path $file -leaf)
			Get-Content -Path $file | ForEach-Object {
				# Old way of splitting file
				#$arr = $_.ToString() -split ','				
				#$left = $arr[0..($arr.Length-3)] -join ','
				#$right = $arr[($arr.Length-2)..($arr.Length-1)] -join ','					
				#'"' + $pkey + '",' + $left + ',"' + $dmaSourceId + '","' + $dmaManualId + '",' + $right
				#New file split method
				$perfmonCsv = $_.ToString() -split ','
				$perfmonFormattedDate = checkTimestampFormat($perfmonCsv[0])
				'"' + $pkey + '"|' + $perfmonFormattedDate + '|' + $perfmonCsv[1] + '|' + $perfmonCsv[2] + '|' + $perfmonCsv[3] + '|' + $perfmonCsv[4] + '|' + $perfmonCsv[5] + '|' + $perfmonCsv[6] + '|' + $perfmonCsv[7] + '|' + $perfmonCsv[8] + '|' + $perfmonCsv[9] + '|' + $perfmonCsv[10] + '|' + $perfmonCsv[11] + '|' + $perfmonCsv[12] + '|' + $perfmonCsv[13] + '|' + $perfmonCsv[14] + '|' + $perfmonCsv[15] + '|' + $perfmonCsv[16] + '|' + $perfmonCsv[17] + '|' + $perfmonCsv[18] + '|' + $perfmonCsv[19] + '|' + $perfmonCsv[20] + '|' + $perfmonCsv[21] + '|' + $perfmonCsv[22] + '|' + $perfmonCsv[23] + '|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|' + $perfmonCsv[24] + '|' + $perfmonCsv[25]
			} | Out-File -FilePath $env:TEMP\$tempFileName -Encoding utf8
		}
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " Max perfmon file date available: $maxFileDate" -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
	} else {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "No Perfmon Files exist in the $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet Directory. Continuing without Perfmon file." -logOperation "FILE"
		Write-Output "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date))   No Perfmon Files exist in the $env:SystemDrive\PerfLogs\Admin\Google-DMA-SQLServerDataSet Directory. Continuing without Perfmon file." | Yellow
		$fileExists = $false
	}

	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Concatenating and adding header to perfmon files..." -logOperation "BOTH"
	$tempContent = '"PKEY"|"COLLECTION_TIME"|"AVAILABLE_MBYTES"|"PHYSICALDISK_AVG_DISK_BYTES_READ"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE"|"PHYSICALDISK_AVG_DISK_BYTES_READ_SEC"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC"|"PHYSICALDISK_DISK_READS_SEC"|"PHYSICALDISK_DISK_WRITES_SEC"|"PROCESSOR_IDLE_TIME_PCT"|"PROCESSOR_TOTAL_TIME_PCT"|"PROCESSOR_FREQUENCY"|"PROCESSOR_QUEUE_LENGTH"|"BUFFER_CACHE_HIT_RATIO"|"CHECKPOINT_PAGES_SEC"|"FREE_LIST_STALLS_SEC"|"PAGE_LIFE_EXPECTANCY"|"PAGE_LOOKUPS_SEC"|"PAGE_READS_SEC"|"PAGE_WRITES_SEC"|"USER_CONNECTION_COUNT"|"MEMORY_GRANTS_PENDING"|"TARGET_SERVER_MEMORY_KB"|"TOTAL_SERVER_MEMORY_KB"|"BATCH_REQUESTS_SEC"|"DMA_SOURCE_ID"|"DMA_MANUAL_ID"|"NUMA_TOTAL_MEMORY_MB"|"NUMA_AVAILABLE_MEMORY_MB"'
	if ($fileExists)  {
		Set-Content -Path $outputDir\$outputFileName -Value $tempContent -Encoding utf8
		
		((Get-Content -Path $env:TEMP\PKEY_*$dataSet*.csv -Raw ) -replace ',','|') | Add-Content -Encoding utf8 -Path $outputDir\$outputFileName
	} else {
		Set-Content -Path $outputDir\$outputFileName -Value $tempContent -Encoding utf8

		#$tempDate = Get-Date -Format "MM/dd/yyyy HH:mm:ss.fff"
		$tempDate = checkTimestampFormat((Get-Date -Format "MM/dd/yyyy HH:mm:ss.fff"))
		$tempContent = '"' + $pkey + '"|"' + $tempDate + '"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|"0"|"0"'
		Add-Content -Path $outputDir\$outputFileName -Value $tempContent -Encoding utf8

		$futureDate = (Get-Date).AddMinutes(1)
		#$tempDate = $futureDate.ToString("MM/dd/yyyy HH:mm:ss.fff")
		$tempDate = checkTimestampFormat(($futureDate.ToString("MM/dd/yyyy HH:mm:ss.fff")))
		$tempContent = '"' + $pkey + '"|"' + $tempDate + '"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|"0"|"0"'
		Add-Content -Path $outputDir\$outputFileName -Value $tempContent -Encoding utf8

	}
	if (Test-Path -Path $outputDir\$outputFileName) {
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Clean up Temp File area..." -logOperation "BOTH"
		Remove-Item -Path $env:TEMP\*$dataSet*.csv
	}
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"
	WriteLog -logLocation $foldername\$logFile -logMessage "DMA Source Id: $dmaSourceId " -logOperation "FILE"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"
	WriteLog -logLocation $foldername\$logFile -logMessage "DMA Manual Id: $dmaManualId " -logOperation "FILE"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"
	WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Collecting current state of perfmon dataset: $dataset..." -logOperation "BOTH"
	logman.exe query -n $dataset | out-string | Add-Content -Encoding utf8 -Path $outputDir\$perfmonLogFile
}

function CreateEmptyFile
{
	param(
		[string]$dataSet,
		[string]$perfmonOutDir,
		[string]$perfmonOutFile,
		[string]$pkey,
		[string]$logFile,
		[string]$dmaSourceId,
		[string]$dmaManualId
		)

		$outputDir = $PSScriptRoot + "\" + $perfmonOutDir
		$outputFileName = $perfmonOutFile
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Creating an empty Google DMA SQL Server Perfmon Counter Data Set..." -logOperation "BOTH"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"
		WriteLog -logLocation $foldername\$logFile -logMessage "DMA Source Id: $dmaSourceId " -logOperation "FILE"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"
		WriteLog -logLocation $foldername\$logFile -logMessage "DMA Manual Id: $dmaManualId " -logOperation "FILE"
		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "FILE"

		if (!(Test-Path -PathType container $outputDir)) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Creating Output Directory..." -logOperation "BOTH"
			$null = New-Item -ItemType Directory -Path $outputDir
		}

		$tempContent = '"PKEY"|"COLLECTION_TIME"|"AVAILABLE_MBYTES"|"PHYSICALDISK_AVG_DISK_BYTES_READ"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE"|"PHYSICALDISK_AVG_DISK_BYTES_READ_SEC"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC"|"PHYSICALDISK_DISK_READS_SEC"|"PHYSICALDISK_DISK_WRITES_SEC"|"PROCESSOR_IDLE_TIME_PCT"|"PROCESSOR_TOTAL_TIME_PCT"|"PROCESSOR_FREQUENCY"|"PROCESSOR_QUEUE_LENGTH"|"BUFFER_CACHE_HIT_RATIO"|"CHECKPOINT_PAGES_SEC"|"FREE_LIST_STALLS_SEC"|"PAGE_LIFE_EXPECTANCY"|"PAGE_LOOKUPS_SEC"|"PAGE_READS_SEC"|"PAGE_WRITES_SEC"|"USER_CONNECTION_COUNT"|"MEMORY_GRANTS_PENDING"|"TARGET_SERVER_MEMORY_KB"|"TOTAL_SERVER_MEMORY_KB"|"BATCH_REQUESTS_SEC"|"DMA_SOURCE_ID"|"DMA_MANUAL_ID"|"NUMA_TOTAL_MEMORY_MB"|"NUMA_AVAILABLE_MEMORY_MB"'
		Set-Content $env:TEMP\emptyStrings.csv -Value $tempContent -Encoding utf8

		#$tempDate = Get-Date -Format "MM/dd/yyyy HH:mm:ss.fff"
		$tempDate = checkTimestampFormat((Get-Date -Format "MM/dd/yyyy HH:mm:ss.fff"))
		$tempContent = '"' + $pkey + '"|"' + $tempDate + '"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|"0"|"0"'
		Add-Content $env:TEMP\emptyStrings.csv -Value $tempContent -Encoding utf8

		$futureDate = (Get-Date).AddMinutes(1)
		#$tempDate = $futureDate.ToString("MM/dd/yyyy HH:mm:ss.fff")
		$tempDate = checkTimestampFormat(($futureDate.ToString("MM/dd/yyyy HH:mm:ss.fff")))
		$tempContent = '"' + $pkey + '"|"' + $tempDate + '"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"0"|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|"0"|"0"'
		Add-Content $env:TEMP\emptyStrings.csv -Value $tempContent -Encoding utf8

		WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Concatenating and adding header to perfmon files to $outputFileName ..." -logOperation "BOTH"
		((Get-Content -Path $env:TEMP\emptyStrings.csv -Raw ) -replace ',','|') | Set-Content -Encoding utf8 -Path $outputDir\$outputFileName

		if (Test-Path -Path $outputDir\$outputFileName) {
			WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Clean up Temp File area..." -logOperation "BOTH"
			Remove-Item -Path $env:TEMP\*$dataSet*.csv
		}

		if (Test-Path -Path $env:TEMP\emptyStrings.csv) {
			Remove-Item -Path $env:TEMP\emptyStrings.csv
		}
	}

if (!$operation) {
	$operation = read-host -Prompt "Enter an operation: create, stop, delete, collect, createemptyfile"
}
if ($namedInstanceName) {
	$datasetName = "Google-DMA-SQLServerDataSet-$namedInstanceName"
} else {
	$datasetName = "Google-DMA-SQLServerDataSet-MSSQLSERVER"
}

if (!(Test-Path -Path $PSScriptRoot\$perfmonOutDir)) {
	$null = New-Item -Name $PSScriptRoot\$perfmonOutDir -ItemType Directory
	WriteLog -logLocation $PSScriptRoot\$perfmonOutDir\$logFile -logMessage "Creating log directory..." -logOperation "MESSAGE"
	Remove-Item -Path $env:TEMP\tempDisk.csv
}


if ($operation.ToLower() -eq "create") {
	CreateDMAPerfmonDataSet -instanceName $namedInstanceName -dataSet $datasetName -perfmonOutDir $perfmonOutDir -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "start") {
	StartDMAPerfmonDataSet -dataSet $datasetName -perfmonOutDir $perfmonOutDir -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "stop") {
	StopDMAPerfmonDataSet -dataSet $datasetName -perfmonOutDir $perfmonOutDir -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "delete") {
	DeleteDMAPerfmonDataSet -dataSet $datasetName -perfmonOutDir $perfmonOutDir -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "collect") {
	CollectDMAPerfmonDataSet -dataSet $datasetName -perfmonOutDir $perfmonOutDir -perfmonOutFile $perfmonOutFile -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $dmaManualId -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "createemptyfile") {
	CreateEmptyFile -dataSet $datasetName -perfmonOutDir $perfmonOutDir -perfmonOutFile $perfmonOutFile -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $dmaManualId -logFile $perfmonLogFile
} elseif ($operation.ToLower() -eq "status") {
	StatusDMAPerfmonDataSet -dataSet $datasetName -perfmonOutDir $perfmonOutDir -logFile $perfmonLogFile
} else {
	Write-Output "Operation $operation specified is invalid"
}
