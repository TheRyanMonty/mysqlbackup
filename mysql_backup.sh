#!/bin/bash
################################################################################
##
##      mysql_backup.sh
##
################################################################################
#Usage:
#CRON:
  # Example cron job for daily db backup at midnight
  # min  hr mday month wday command
  # 0    0  *    *     *    /<script_path>/mysql_backup.sh -c <conf_file_path>/<name>.conf

#RESTORE FROM BACKUP
#  zcat [backupfile.sql.gz] | mysql -u [uname] -p[pass] [dbname]

################################################################################
## Functions
################################################################################

ImportGlobalFunctions() {
############################################################################
### ImportGlobalFunctions - Purpose is to import needed functions
############################################################################
#Define script execution directory for Importing Global Functions
script_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

#Importing functions
for func_file in ${script_dir}/funcs/*.func; do
	source ${func_file}
done
}

SetConfig() {
############################################################################
### SetConfig - Purpose is to set the config file from user argument
############################################################################

#Check if arguments are passed in, if not prompt the user
if [ $# = 0 ]
	then
		printf "Please specify -c and the path to the config file. \n"
        exit 1
	else
		for argument in $*; do
			case $argument in
				'-c')  
                    config_path=`echo $* | sed -e 's/.*-c //' | sed -e 's/ -.*//g'` ;;
				\?) printf "\nERROR:  \"$argument\" is not a valid argument.\n"
                    exit 1
			esac
		done
fi

unset argument

}

SourceConfig() {
#Attempt to read the config file
if [[ -r ${config_path} ]]; then
	#Import configuration file
	source ${config_path}
else
	printf "${config_path} does not exist or is not readable, exiting...\n"
	exit 1
fi

}

ValidateConfig() {
#Validate configuration file, ensure path exists and is readables
if [ ! -r ${BACKUP_DIR} ]; then
    echo "Path ${BACKUP_DIR} is not readable! Exiting..."
    exit 1
fi 
}

DeleteOldBackups () {
echo "Deleting $BACKUP_DIR/*.sql.gz older than $KEEP_BACKUPS_FOR days"
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +$KEEP_BACKUPS_FOR -exec rm {} \;
CaptureExitCode
VerifyExitCode
}

MysqlLogin() {
if [ -n "$MYSQL_SERVER" ]; then
    local mysql_login+=" -h$MYSQL_SERVER " 
fi
if [ -n "$MYSQL_PORT" ]; then
    local mysql_login+=" -P$MYSQL_PORT " 
fi
local mysql_login+="-u $MYSQL_UNAME " 
if [ -n "$MYSQL_PWORD" ]; then
    local mysql_login+=" -p$MYSQL_PWORD " 
fi
echo $mysql_login
}

DatabaseList() {
local show_databases_sql="SHOW DATABASES WHERE \`Database\` NOT REGEXP '$IGNORE_DB'"
echo $(mysql $(MysqlLogin) -e "$show_databases_sql"|awk -F " " '{if (NR!=1) print $1}')
}

EchoStatus() {
printf '\r'; 
printf ' %0.s' {0..100} 
printf '\r'; 
printf "$1"'\r'
}

BackupDatabase() {
backup_file="$BACKUP_DIR/$TIMESTAMP.$database.sql.gz" 
output+="$database => $backup_file\n"
EchoStatus "...backing up $count of $total databases: $database"
$(mysqldump $(MysqlLogin) $database | gzip -9 > $backup_file)
CaptureExitCode
VerifyExitCode
}

BackupDatabases() {
  local databases=$(DatabaseList)
  local total=$(echo $databases | wc -w | xargs)
  local output=""
  local count=1
  for database in $databases; do
    BackupDatabase
    CaptureExitCode
    VerifyExitCode
    local count=$((count+1))
  done
  echo -ne $output | column -t
}

hr() {
  printf '=%.0s' {1..100}
  printf "\n"
}

###########################################################
### Main execution area
###########################################################
ImportGlobalFunctions
SetConfig $*
SourceConfig
ValidateConfig
DeleteOldBackups
hr
BackupDatabases
hr
printf "All backed up!\n\n"