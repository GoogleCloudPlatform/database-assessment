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
    The target computer name to collect the HW specs from (Required).
.PARAMETER outputPath
    The output full path of the csv that this scripts creates (Required).
.PARAMETER pkey
    Final Output Directory (Required).
.PARAMETER dmaSourceId
    DMA derived unique id (Required).
.PARAMETER dmaManualId
    Customer Manual Unique ID or dma manual unique id (Optional).
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
	)][string]$dmaManualId="NA"
)

try {
	Write-Host "Params: computer:$computerName, dma_src: $dmaSourceId, output:$outputPath"

	$credential = $null
	# This will create a pop up for the user to enter credentials for shape sizing collection.
	if ($computerName -ne $env:COMPUTERNAME) {
		Write-Host "Identified a remote computer, please add credentials"
       $credential = Get-Credential -Message "Please enter system credentials for machine shape sizing:"
	}

	# Logical cores count.
	$cores=(Get-WmiObject Win32_Processor -Credential $credential -ComputerName $computerName | Measure-Object -Property NumberOfCores -Sum).Sum
	
	# Total memory in bytes.
	$memoryBytes=(Get-WmiObject Win32_PhysicalMemory -Credential $credential -ComputerName $computerName | Measure-Object -Property Capacity -Sum).Sum
	
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
	Write-Host "Success to retrieve information from $computerName."
}
catch {
	Write-Host "Failed to retrieve information from $computerName."
}