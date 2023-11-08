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
    Collects HW Specs using Get-WmiObject to be uploaded to Google Database Migration Assistant for MS SQL Server.
.PARAMETER computerName
    The target computer name to collect the HW specs from (Optional).
.PARAMETER outputPath
    The output full path of the csv that this scripts creates (Required).
.PARAMETER pkey
    Final Output Directory (Required).
.PARAMETER dmaSourceId
    DMA derived unique id (Required).
.PARAMETER dmaManualId
    Customer Manual Unique ID or dma manual unique id (Optional).
.PARAMETER logLocation
    Location of log file to output the script (Optional).
.EXAMPLE
    C:\dmaSQLServerHWSpecs.ps1 -computerName localhost -outputPath a.out -pkey pkey1 -dmaSourceId src1
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
param (
	[Parameter(
		Mandatory=$False,
		HelpMessage="The computer name"
	)][string]$computerName = $env:COMPUTERNAME,
	[Parameter(
		Mandatory=$True,
		HelpMessage="The Output path"
	)][string]$outputPath,
	[Parameter(
		Mandatory=$True,
		HelpMessage="The pkey value"
	)][string]$pkey,
	[Parameter(
		Mandatory=$True,
		HelpMessage="The dma_source_id"
	)][string]$dmaSourceId,
	[Parameter(
		Mandatory=$False,
		HelpMessage="The dma_manual_id"
	)][string]$dmaManualId="NA",
	[Parameter(
		Mandatory=$False,
		HelpMessage="The log file location"
	)][string]$logLocation="$PSScriptRoot\dmaSqlServerHWSpecs.log"
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

try {
	WriteLog -logLocation $logLocation -logMessage "Fetching machine HW specs from computer:$computerName and storing it in output:$outputPath" -logOperation "FILE"

	# Logical cores count.
	$cores=(Get-WmiObject Win32_Processor -ComputerName $computerName | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
	
	# Total memory in bytes.
	$memoryBytes=(Get-WmiObject Win32_PhysicalMemory -ComputerName $computerName | Measure-Object -Property Capacity -Sum).Sum
	
	# CSV data.
	$csvData = [PSCustomObject]@{
		"pkey" = $pkey
		"dma_source_id" = $dmaSourceId
		"dma_manual_id" = $dmaManualId
		"computer_name" = $computerName
		"cores" = $cores
		"memory_bytes" = $memoryBytes
	}
	
	# Writing to csv.
	$csvData | Export-Csv -Path $outputPath -Delimiter "|" -NoTypeInformation
	WriteLog -logLocation $logLocation -logMessage "Successfully fetched machine HW specs of $computerName to output:$outputPath" -logOperation "FILE"	
}
catch {
	WriteLog -logLocation $logLocation -logMessage "ERROR - Failed fetching machine HW specs of $computerName" -logOperation "FILE"	
}