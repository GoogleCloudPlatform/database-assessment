# Gather workload metadata

## Execute collection script

Download the latest collection scripts here.

Extract these files to a location that has access to the database from SQL\*Plus

- Execute this from a system that can access your database via sqlplus
- Pass connect string as input to this script (see below for example)
- NOTE: If this is an Oracle RAC and/or PDB environment you just need to run it once per database. No need to run in each PDB or in each Oracle RAC instance.

```shell
cd /collector

./collectData-Step1.sh optimusprime/Pa55w__rd123@//{db host/scan address}/{service name}
```

1.5. Once the script is executed you should see many opdb\*.log output files generated. It is recommended to zip/tar these files.

- All the generated files follow this standard `opdb__<queryname>__<dbversion>_<scriptversion>_<hostname>_<dbname>_<instancename>_<datetime>.log`
- Use meaningful names when zip/tar the files.

Example output:

```shell
oracle@oracle12c oracle-database-assessment-output]$ ls
manual__alertlog__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log            opdb__dbsummary__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistcmdtypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log       opdb__freespaces__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistosstat__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log         opdb__indexestypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__awrhistsysmetrichist__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log  opdb__partsubparttypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__compressbytable__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log       opdb__patchlevel__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__compressbytype__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log        opdb__pdbsinfo__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__cpucoresusage__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log         opdb__pdbsopenmode__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__datatypes__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log             opdb__sourcecode__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbfeatures__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log            opdb__spacebyownersegtype__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbhwmarkstatistics__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log    opdb__spacebytablespace__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbinstances__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log           opdb__systemstats__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dblinks__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log               opdb__tablesnopk__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbobjects__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log             opdb__usedspacedetails__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbparameters__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log          opdb__usrsegatt__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log
opdb__dbservicesinfo__122_0.1.1_oracle12c.ORCL.orcl.080421224807.log

```
