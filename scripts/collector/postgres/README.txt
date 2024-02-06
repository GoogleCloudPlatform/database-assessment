README
======
Instructions on how to prepare and run Google Database Migration Assessment Data Extractor to extract the data required
for analysis by Database Migration Assessment.

1. Background
-------------

    This utility extracts metadata about the tables, partitions and SQL workload in a database into CSV files.
    These CSV files are then used by Database Migration Assessment internally to analyze the data with Google Database Migration Assessment.

    b) Database Privileges
    ----------------------
    TBD

    c) System Requirements
    ----------------------
    The collection script depends on the following to be available on the machine from which it is run:
    bash shell
    cat
    cut
    dirname
    grep
    locale
    mkdir
    sed
    tar
    tr
    which
    zip or gzip


2. Preparation
--------------

    a) Unzip the install archive.

    b) TBD

3. Execution
------------

    TBD


4. Results
----------

    An archive of the extracted results will be created in the directory collector/output.
    The full path and file name will be displayed on completion.


5. License
------------
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
