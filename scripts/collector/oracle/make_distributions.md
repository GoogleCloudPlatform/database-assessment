# PRD: DMA Collector Build Process

## 1. Introduction

This document describes the process for building the various versions of the Database Migration Assessment (DMA) collector. The build process is controlled by a series of configuration files and shell scripts that work together to generate customized SQL scripts for different database versions and configurations.

## 2. Components

The build process consists of the following key components:

*   **`make_distributions.sh`**: This is the main build script. It reads the `distributions.config` file to determine which versions of the collector to build, and then uses the `variables_*.txt` files to perform variable substitutions on the base SQL files.
*   **`distributions.config`**: This configuration file controls which versions of the DMA collector are built. Each line in the file specifies a different combination of database version, tenancy, performance stats source, and Data Guard role.
*   **`variables_*.txt`**: These files control the variable substitutions that are made to the base SQL files. There is a separate file for each database version, and the files contain a series of key-value pairs that are used to replace placeholders in the SQL scripts.
*   **`sql/**`**: This directory tree contains the base SQL files that are used to generate the final SQL distributions. The files are organized into subdirectories based on their function, and they contain placeholders that are replaced by the `make_distributions.sh` script.

## 3. Process Overview

The build process works as follows:

1.  The `make_distributions.sh` script is executed.
2.  The script reads the `distributions.config` file to determine which versions of the collector to build.
3.  For each version of the collector, the script:
    1.  Reads the appropriate `variables_*.txt` files to determine the variable substitutions to be made.
    2.  Applies the variable substitutions to the base SQL files in the `sql/**` directory.
    3.  Generates the final SQL distribution in a new directory.

## 4. Configuration

The build process can be configured by modifying the following files:

*   **`distributions.config`**: To build a new version of the collector, add a new line to this file with the desired configuration.
*   **`variables_*.txt`**: To change the variable substitutions for a particular database version, modify the appropriate `variables_*.txt` file.

## 5. Execution

To build the DMA collector, execute the `make_distributions.sh` script. The script will generate the final SQL distributions in the `dist` directory.
