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
    This is a powershell module which can be imported into other powershell scripts for function reuse
.NOTES
        https://googlecloudplatform.github.io/database-assessment/
#>

function testDirectoryLength {
    param (
        [Parameter(Mandatory=$true)][string]$directory
    )
    $folderLength = ($directory).Length
    if ($folderLength -gt 260) {
        Write-Output "Folder length + output file name exceeds 260 characters."
        Write-Output "Execute collection from a path with less characters"
        Exit 1
    }
}


