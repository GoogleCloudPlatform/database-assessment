--Registry for MSDTC
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSDTC\Security" /v NetworkDtcAccess
SET @REGKEY = 'System\CurrentControlSet\Services\'+@SQLSrv
INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

--CLR
Declare @UserCLRObjects Table (a int);
insert into @UserCLRObjects exec sp_MSforeachdb 'Select count(*) a From ?..sysobjects where ObjectProperty(id, ''IsMSShipped') =0 and (xtype ='FS' or type ='FT' or type ='TA' or type ='PC'); 
select SUM(a) UserCLRObjects from @UserCLRObjects;

Declare @UserCLRObjects Table (a int);insert into @UserCLRObjects exec sp_MSforeachdb ''Select count(*) a From ?..sysobjects where ObjectProperty(id, ''''IsMSShipped'''') =0 and (xtype =''''FS'''' or type =''''FT'''' or type =''''TA'''' or type =''''PC''''); '' select SUM(a) UserCLRObjects from @UserCLRObjects;
