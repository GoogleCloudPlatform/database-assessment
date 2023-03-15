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

Param(
[Parameter(Mandatory=$false)][string]$collectionUserName="userfordma",
[Parameter(Mandatory=$false)][string]$CollectionUserPass="P@ssword135"
)

$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
    sqlcmd -S $sqlsrv -i sql\prereq_createsa.sql -m 1 -v collectionUser=$collectionUserName collectionPass=$CollectionUserPass
}
