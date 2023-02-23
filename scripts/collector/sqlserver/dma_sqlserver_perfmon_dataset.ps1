param (
  [string]$operation, 
  [string]$mssqlInstanceName=$null
  )
function CreateDMAPerfmonDataSet 
{
    param(
        [string]$instanceName=$null
        )
if ($instanceName) {
$str = @'
<DataCollectorSet>
	<Status>1</Status>
	<Duration>691200</Duration>
	<Description>
	</Description>
	<DescriptionUnresolved>
	</DescriptionUnresolved>
	<DisplayName>
	</DisplayName>
	<DisplayNameUnresolved>
	</DisplayNameUnresolved>
	<SchedulesEnabled>-1</SchedulesEnabled>
	<LatestOutputLocation>C:\PerfLogs\Admin\DMA-SQLServerDataSet\</LatestOutputLocation>
	<Name>DMA-SQLServerDataSet</Name>
	<OutputLocation>C:\PerfLogs\Admin\DMA-SQLServerDataSet\</OutputLocation>
	<RootPath>%systemdrive%\PerfLogs\Admin\DMA-SQLServerDataSet</RootPath>
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
		<FileName>DMA-SQLServerDataSet</FileName>
		<FileNameFormat>3</FileNameFormat>
		<FileNameFormatPattern>NddMMyyyy</FileNameFormatPattern>
		<LogAppend>0</LogAppend>
		<LogCircular>0</LogCircular>
		<LogOverwrite>0</LogOverwrite>
		<LatestOutputLocation></LatestOutputLocation>
		<DataSourceName>
		</DataSourceName>
		<SampleInterval>10</SampleInterval>
		<SegmentMaxRecords>552960</SegmentMaxRecords>
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
'@ } else {
$str = @'
<DataCollectorSet>
	<Status>1</Status>
	<Duration>691200</Duration>
	<Description>
	</Description>
	<DescriptionUnresolved>
	</DescriptionUnresolved>
	<DisplayName>
	</DisplayName>
	<DisplayNameUnresolved>
	</DisplayNameUnresolved>
	<SchedulesEnabled>-1</SchedulesEnabled>
	<LatestOutputLocation>C:\PerfLogs\Admin\DMA-SQLServerDataSet\</LatestOutputLocation>
	<Name>DMA-SQLServerDataSet</Name>
	<OutputLocation>C:\PerfLogs\Admin\DMA-SQLServerDataSet\</OutputLocation>
	<RootPath>%systemdrive%\PerfLogs\Admin\DMA-SQLServerDataSet</RootPath>
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
		<FileName>DMA-SQLServerDataSet</FileName>
		<FileNameFormat>3</FileNameFormat>
		<FileNameFormatPattern>NddMMyyyy</FileNameFormatPattern>
		<LogAppend>0</LogAppend>
		<LogCircular>0</LogCircular>
		<LogOverwrite>0</LogOverwrite>
		<LatestOutputLocation></LatestOutputLocation>
		<DataSourceName>
		</DataSourceName>
		<SampleInterval>10</SampleInterval>
		<SegmentMaxRecords>552960</SegmentMaxRecords>
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
	$instanceName = "MSSQL`$" + $instanceName
	$perfmonDataSetExists = logman.exe query -n DMA-SQLServerDataSet
	if ($perfmonDataSetExists -Like "*Data Collector Set was not found*") {
		Write-Output "Beginning Creation of the Google DMA SQL Server Perfmon Counter Data Set"
		if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv) {
			Write-Output ""
			Write-Output "Removing old perfmon data files"
			Remove-Item -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv
		}
	} else {
		Write-Output ""
		Write-Output "Google DMA SQL Server Perfmon Counter Data Set found....."
		Write-Output ""
		Write-Output "Stopping Google DMA SQL Server Perfmon Counter Data Set"
		logman.exe stop -n DMA-SQLServerDataSet
		Write-Output ""
		Write-Output "Deleting Google DMA SQL Server Perfmon Counter Data Set"
		logman.exe delete -n DMA-SQLServerDataSet
		if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv) {
			Write-Output ""
			Write-Output "Removing old perfmon data files"
			Remove-Item -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv
		}
		if (Test-Path -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml) {
			Write-Output ""
			Write-Output "Removing old perfmon template file"
			Remove-Item -Path $env:TEMP\DMA-SQLServerPerfmonDataSet.xml
		}
	}
	
	$newXML = $str.Replace('$instance', $instanceName)
	
	Write-Output ""
	Write-Output "Writing XML File to be used for import to perfmon"
	$newXML | Out-File -FilePath $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml -encoding utf8

	Write-Output ""
	Write-Output "Importing Google DMA SQL Server Perfmon Counter Data Set from Template"
	logman.exe import -n DMA-SQLServerDataSet -xml (Get-ChildItem -Path $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml | ForEach-Object { $_.FullName })

	Write-Output ""
	Write-Output "Starting Google DMA SQL Server Perfmon Counter Data Set"
	logman.exe start -n DMA-SQLServerDataSet

	$debug_flag = $null

	if ($debug_flag) {
		Write-Output "Display template being used for import: "
		Write-Output $newXML
		Write-Output "XML Output Directory: $xmlTempDir"
		Write-Output "Passed in Instance Name: $instanceName"
		Write-Output "Directory Listing of $xmlTempDir"
			Get-ChildItem -Path $xmlTempDir\DMA-SQLServerPerfmonDataSet.xml
		Write-Output "Directory Listing of $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet"
			Get-ChildItem -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet
	}

}
function StopDMAPerfmonDataSet
{
	Write-Output "Stopping Google DMA SQL Server Perfmon Counter Data Set"
	logman.exe stop -n DMA-SQLServerDataSet
}
function DeleteDMAPerfmonDataSet
{
	$perfmonDataSetRunning = logman.exe query -n DMA-SQLServerDataSet

	if ($perfmonDataSetRunning -like "*Status:               Running*") {
		Write-Output "Google DMA SQL Server Perfmon Counter Data Set is running... Stopping Data Collector Set before deletion."
		logman.exe stop -n DMA-SQLServerDataSet
		logman.exe delete -n DMA-SQLServerDataSet
	} else {
		Write-Output "Google DMA SQL Server Perfmon Counter Data Set found, but not running..... Deleting"
		logman.exe delete -n DMA-SQLServerDataSet
	}
}
function CollectDMAPerfmonDataSet
{
	Write-Output "Collecting results from the Google DMA SQL Server Perfmon Counter Data Set."
	$perfmonDataSetRunning = logman.exe query -n DMA-SQLServerDataSet
	$userDownloadsDir = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

	if ($perfmonDataSetRunning -like "*Status:               Running*") {
		Write-Output ""
		Write-Output "Google DMA SQL Server Perfmon Counter Data Set is running... Stopping Data Collector Set before deletion."
		logman.exe stop -n DMA-SQLServerDataSet
	}
	if (Test-Path -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv) {
		Write-Output ""
		Write-Output "Moving perfmon datafiles to the $userDownloadsDir Directory"
		Copy-Item -Path $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet\*.csv -Destination $userDownloadsDir
		Write-Output ""
		Write-Output "Creating tar of perfmon datafiles in the $userDownloadsDir Directory"
		tar.exe cvf $userDownloadsDir\DMA-SQLServerPerfmon.tar -C $userDownloadsDir MS-SERVER1_DMA*.csv
	} else {
		Write-Output ""
		Write-Output "No Perfmon Files exist in the $env:SystemDrive\PerfLogs\Admin\DMA-SQLServerDataSet Directory"
	}

}

if (!$operation) {
	$operation = read-host -Prompt "Enter an operation: create, stop, delete, collect" 
}
if ($operation.ToLower() -eq "create") {
	CreateDMAPerfmonDataSet -instanceName $mssqlInstanceName
} elseif ($operation.ToLower() -eq "stop") {
	StopDMAPerfmonDataSet
} elseif ($operation.ToLower() -eq "delete") {
	DeleteDMAPerfmonDataSet
} elseif ($operation.ToLower() -eq "collect") {
	CollectDMAPerfmonDataSet
} else {
	Write-Output "Operation $operation specified is invalid"
}