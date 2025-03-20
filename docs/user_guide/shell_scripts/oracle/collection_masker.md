# Masking a collection

While the collection script does not gather any data or source code, it does contain the name of schemas and hostname information. If there is a requirement to obfuscate this data, there is an optional masking script included with the scripts.

This one-way script will create a key file that maps the anonymized schema and hostname attributes to its original name.  This anonymized data can not be reversed in any way and requires the key to be decoded.  It currently is only supported for Oracle database collections.

**Note** This file should not be sent with the collection and should not be lost, as it can't be recreated.

## Executing the script

The script can be executed at the shell or command prompt and requires 2 parameters:

- Path containing the collection archives you would like to mask. You should place the entire `zip` or `tar.gz` file in this folder, and you can include multiple collections with a single execution of the tool.
- Output directory is the path to write the masked collection archive.

```bash
$ ./masker/dma-collection-masker
usage: dma-collection-masker [-h] [--verbose]
  [--collection-path COLLECTION_PATH] [--output-path OUTPUT_PATH]

Google Database Migration Assessment - Collection Masking Script

options:
  -h, --help            show this help message and exit
  --verbose, -v         Logging level: 0: ERROR, 1: INFO, 2: DEBUG
  --collection-path COLLECTION_PATH
                        Path to search for collections.
  --output-path OUTPUT_PATH
                        Path to write masked collections.
```

## Installation Note

The only requirement this script has is the `packaging` Python repository.  This is likely already installed in your environment as it is part of many core packages.

However, if you receive an error related to importing this package, please run:

```shell
pip install -U packaging
```
