SET NOCOUNT ON
DECLARE
@User_Build [varchar] (256),
@errStatement [varchar](8000),
@msgStatement [varchar](8000),
@DatabaseUserName [sysname],
@DatabaseName [sysname],
@DBname [sysname],
@ServerUserName [sysname],
@DefaultSchema [varchar] (256),
@RoleName [varchar](256),
@MemberName [varchar](256),
@PrivState [varchar] (256),
@PrivGrantee [varchar] (256),
@PrivType [varchar] (256),
@PrivWG [varchar] (256),
@SchState [varchar] (256),
@SchType [varchar] (256),
@SchName [varchar] (256),
@SchWG [varchar] (256),
@SchGrantee [varchar] (256),
@ObjState [varchar] (256),
@ObjType [varchar] (256),
@ObjSchema [varchar] (256),
@ObjName [varchar] (256),
@ObjGrantee [varchar] (256),
@ObjWG [varchar] (256),
@binpwd varbinary (256),
@SID_varbinary varbinary(85),
@SID_string varchar(256),
@login_expired varchar(256),
@login_policy varchar(256),
@login_name varchar (256),
@user_name varchar (256),
@schema_name varchar (256),
@txtpwd sysname,
@default_database varchar (256),
@default_lang varchar (256),
@login_type varchar (256)

SET @msgStatement = '/* user_extraction script written by Nicole Harrington 9/25/2014'
PRINT @msgStatement
SET @msgStatement = 'You will need stored procedure dbo.sp_hexadecimal to run this.'
PRINT @msgStatement
SET @msgStatement = '  '
PRINT @msgStatement
SET @msgStatement = '1. Run this script against the instance that you would like to extract the login and mapped user from'
PRINT @msgStatement
SET @msgStatement = '2. Copy the output to a new query window and run section by section (eg. -- CREATE USERS) against the instance you would like it in'
PRINT @msgStatement
SET @msgStatement = '  '
PRINT @msgStatement
SET @msgStatement = '** Generated '+ CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
PRINT @msgStatement
PRINT ''
-- Change the User_Build to the user you want cloned
SET @User_Build = 'ph'
PRINT 'for user ' + @User_Build
--
-- Script to CREATE LOGINS for instance
PRINT '-- CREATE LOGINS'
DECLARE @query as varchar(2000)
SET @query =N'select [master].[sys].[server_principals].[name] COLLATE LATIN1_General_CI_AI  as login_name,
         ISNULL ([sys].[database_principals].[default_schema_name],'''') as schema_name,
         [master].[sys].[server_principals].[default_database_name] as default_database,
         [master].[sys].[server_principals].[default_language_name] as default_lang,
         [master].[sys].[server_principals].[type] as login_type,
         [master].[sys].[sql_logins].[password_hash] as binpwd,
         [master].[sys].[sql_logins].[sid] as login_sid,
         [master].[sys].[sql_logins].[is_disabled] as login_expired,
         [master].[sys].[sql_logins].[is_policy_checked] as login_policy
         into ##logins
from [sys].[database_principals] RIGHT OUTER JOIN [master].[sys].[server_principals] 
on [sys].[database_principals].[name]=[master].[sys].[server_principals].[name] COLLATE LATIN1_General_CI_AI
LEFT OUTER JOIN [master].[sys].[sql_logins] 
on [master].[sys].[server_principals].[name] = [master].[sys].[sql_logins].[name] COLLATE LATIN1_General_CI_AI
where [master].[sys].[server_principals].[type] in (''U'', ''G'', ''S'') 
AND [master].[sys].[server_principals].[name] = '+ '''' + @User_Build + ''''
--select @query
exec (@query)
DECLARE _logins
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
select * from ##logins
 
OPEN _logins FETCH NEXT FROM _logins INTO @login_name, @schema_name, @default_database, @default_lang, @login_type, @binpwd, @SID_varbinary, @login_expired, @login_policy
WHILE @@FETCH_STATUS = 0
	BEGIN	
		EXEC sp_hexadecimal @SID_varbinary, @SID_string OUT
		SET @SID_string = ', SID=' + @SID_string
					
		IF (@binpwd IS NOT NULL)
			-- Non-null password
			EXEC master.dbo.sp_hexadecimal @binpwd, @txtpwd OUT
		ELSE
			-- Null password
			SET @txtpwd = ''	
			
		
		IF (@login_expired IS NOT NULL)
			IF (@login_expired = 0)
				SET @login_expired = ', CHECK_EXPIRATION=OFF'	
			ELSE
				SET @login_expired = ', CHECK_EXPIRATION=ON'
		ELSE
			SET @login_expired = ''

		IF (@login_policy IS NOT NULL)			
			IF (@login_policy = 0)
				SET @login_policy = ', CHECK_POLICY=OFF'
			ELSE
				SET @login_policy = ', CHECK_POLICY=ON'
		ELSE
			SET @login_policy = ''
						
		SET @msgStatement =
		(CASE 
			WHEN @login_type = 'U' OR @login_type = 'G'
				THEN 'CREATE LOGIN ' + @login_name + ' FROM WINDOWS WITH DEFAULT_DATABASE=' + @default_database + ', DEFAULT_LANGUAGE=' + @default_lang + @login_expired + @login_policy
			WHEN @login_type = 'S'
				THEN 'CREATE LOGIN ' + @login_name + ' WITH PASSWORD=' + @txtpwd + ' HASHED, DEFAULT_LANGUAGE=' + @default_lang + @login_expired + @login_policy + @SID_string
			ELSE
			'None available'
		END)

PRINT @msgStatement
FETCH NEXT FROM _logins INTO @login_name, @schema_name, @default_database, @default_lang, @login_type, @binpwd, @SID_varbinary, @login_expired, @login_policy
END

CLOSE _logins 
DEALLOCATE _logins --cleanup cursor
DROP TABLE ##logins

--Script CREATE USERS for current database
CREATE TABLE ##users (
    LoginName nvarchar(max),
    DBname nvarchar(max),
    Username nvarchar(max), 
    AliasName nvarchar(max))
INSERT INTO ##users EXEC master..sp_msloginmappings
PRINT ' '
PRINT '-- CREATE USERS'
DECLARE _users
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR
SELECT a.LoginName, DBname, Username, ISNULL (b.[default_schema_name],'') as schema_name 
FROM   ##users a LEFT OUTER JOIN [sys].[database_principals] b
on a.LoginName = b.[name] COLLATE LATIN1_General_CI_AI 
where LoginName = @User_Build
order by DBname

/*
SELECT a.LoginName, DBname, Username, ISNULL (b.[default_schema_name],'') as schema_name 
FROM   ##users a LEFT OUTER JOIN [sys].[database_principals] b
on a.LoginName = b.[name] COLLATE LATIN1_General_CI_AI 
where LoginName = 'ph'
order by DBname
*/

OPEN _users FETCH NEXT FROM _users INTO @DatabaseUserName, @DBname, @ServerUserName, @DefaultSchema
WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN
	If (@DefaultSchema = '')
		BEGIN
			SET @DefaultSchema = ''
		END
	ELSE
		BEGIN
			SET @DefaultSchema = ' WITH DEFAULT_SCHEMA=[' + @DefaultSchema + ']'
		END
	END
SET @msgStatement = 'USE [' + @DBname + ']'
PRINT @msgStatement
PRINT 'GO'
SET @msgStatement = 'CREATE USER ['        ---example: CREATE USER [mlapenna] FOR LOGIN [mlapenna]
 + @DatabaseUserName + ']' + ' FOR LOGIN [' + @ServerUserName + ']' + @DefaultSchema
PRINT @msgStatement

CREATE TABLE ##roles (
    RoleName nvarchar(max))

SET @query = N'select b.[NAME] 
from ' + @DBname + '.[sys].[database_principals] a
inner join ' + @DBname + '.sys.database_role_members d on  a.principal_id=d.role_principal_id
INNER JOIN ' + @DBname + '.sys.database_principals  b on d.member_principal_id=b.principal_id
where    b.name <> ''dbo'' and b.name =  '+ '''' + @User_Build + '''
and a.type=''R'' and a.is_fixed_role != 1 and b.name not like ''public'''
						    
INSERT INTO ##roles Exec (@query)

DECLARE _roles
CURSOR LOCAL FORWARD_ONLY READ_ONLY 
FOR
SELECT *
from ##roles

OPEN _roles FETCH NEXT FROM _roles INTO @RoleName
WHILE @@FETCH_STATUS=0
BEGIN
--SET @msgStatement = 'USE [' + @DBname + ']'
--PRINT @msgStatement
--PRINT 'GO'
SET @msgStatement ='if not exists(SELECT 1 from sys.database_principals where type=''R'' and name ='''
+@RoleName+''' ) '+ CHAR(13) +
'BEGIN '+ CHAR(13) +
'CREATE ROLE  ['+ @RoleName + ']'+CHAR(13) +
'END'
PRINT @msgStatement
FETCH NEXT FROM _roles INTO @RoleName
END

CLOSE _roles
DEALLOCATE _roles --cleanup cursor
drop table ##roles

FETCH NEXT FROM _users INTO @DatabaseUserName, @DBname, @ServerUserName, @DefaultSchema
END
CLOSE _users 
DEALLOCATE _users --cleanup cursor

--Script CREATE Database Roles for current database
PRINT ' '

PRINT '-- ADD ROLE MEMBERS'
CREATE TABLE ##role_membrs (
	DatabaseName nvarchar(max),
    RoleName nvarchar(max),
    MemberName nvarchar(max))

CREATE TABLE ##rolez (
	DatabaseName nvarchar(max),
    RoleName nvarchar(max),
    MemberName nvarchar(max))

DECLARE _users
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
SELECT DBname
FROM   ##users a LEFT OUTER JOIN [sys].[database_principals] b
on a.LoginName = b.[name] COLLATE LATIN1_General_CI_AI 
where LoginName = @User_Build
order by DBname

OPEN _users FETCH NEXT FROM _users INTO @DBname
WHILE @@FETCH_STATUS = 0
BEGIN
--SET @msgStatement = 'USE [' + @DBname + ']'
--PRINT @msgStatement
--PRINT 'GO'
SET @query = N'SELECT a.name , b.name, @DBname
from ' + @DBname + '.sys.database_role_members d 
INNER JOIN ' + @DBname + '.sys.database_principals  a on  d.role_principal_id=a.principal_id 
INNER JOIN ' + @DBname + '.sys.database_principals  b on d.member_principal_id=b.principal_id
where    b.name <> ''dbo'' and b.name = '+ '''' + @User_Build + '''
order by 1,2'

select @DBname
						    
INSERT INTO ##role_membrs Exec (@query)
--insert into ##rolez select @dbname, * from ##role_membrs
select @query
--select * from ##rolez
select * from ##role_membrs



--SET @msgStatement = 'USE [' + @DBname + ']'
--PRINT @msgStatement
--PRINT 'GO'

FETCH NEXT FROM _users INTO @DBname
END
CLOSE _users 
DEALLOCATE _users --cleanup cursor

DECLARE _role_members
CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR 
SELECT *
from ##rolez
 
OPEN _role_members FETCH NEXT FROM _role_members INTO @DatabaseName, @RoleName, @MemberName
WHILE @@FETCH_STATUS = 0
BEGIN

SET @msgStatement = 'USE [' + @DatabaseName + ']'
PRINT @msgStatement
PRINT 'GO'

SET @msgStatement = 'EXEC [sp_addrolemember] ' + '@rolename = [' + @RoleName + '], ' + '@membername = [' + @MemberName + ']'
PRINT @msgStatement
FETCH NEXT FROM _role_members INTO @DatabaseName, @RoleName, @MemberName
END

CLOSE _role_members 
DEALLOCATE _role_members --cleanup cursor
--drop table ##role_membrs
--drop table ##users
--drop table ##rolez

