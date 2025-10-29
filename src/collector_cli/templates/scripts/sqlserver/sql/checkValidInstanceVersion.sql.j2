/*
Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

DECLARE @PRODUCT_VERSION AS INTEGER;
DECLARE @PRODUCT_MAJOR_VERSION AS INTEGER;
DECLARE @PRODUCT_MINOR_VERSION AS INTEGER;
DECLARE @VALID_VERSION AS VARCHAR;
DECLARE @CLOUDTYPE AS VARCHAR(256);

SELECT @PRODUCT_VERSION = CONVERT(INTEGER,REPLACE(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), '.', ''));
SELECT @PRODUCT_MAJOR_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @PRODUCT_MINOR_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 3));
SELECT @CLOUDTYPE = 'NONE';

BEGIN
    IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE';
    IF UPPER(@@VERSION) LIKE '%LINUX%'
	SELECT @CLOUDTYPE = 'LINUX';
END;

IF @PRODUCT_MAJOR_VERSION > 10
    BEGIN
    SELECT @VALID_VERSION = 'Y';
END;
ELSE
BEGIN
    IF (@PRODUCT_MAJOR_VERSION = 10 AND @PRODUCT_MINOR_VERSION >= 50)
    BEGIN
        SELECT @VALID_VERSION = 'Y';
    END;
    ELSE
    BEGIN
        SELECT @VALID_VERSION = 'N';
    END;
END;

SELECT @VALID_VERSION, @CLOUDTYPE;
