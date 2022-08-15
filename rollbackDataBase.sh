#!/bin/bash

function showUsage() {
  echo
  echo Usage: "Edit file db_config with Data Base infos and execute ./rollbackDataBase.sh [DB_VERSION_TO_ROLLBACK]"
  echo
}

function showParameters() {
  echo
  echo "********** Parameters ***********"
  echo
  echo    "DB_VERSION_TO_ROLLBACK: ${DB_VERSION_TO_ROLLBACK}"
  echo    "DB_HOST: ${DB_HOST}"
  echo    "DB_PORT: ${DB_PORT}"
  echo    "DB_USER: ${DB_USER}"
  echo    "DB_PASSWORD: *******"
  echo    "DB_DATABASE_NAME: ${DB_DATABASE_NAME}"
  echo
  echo "*********************************"
  echo
}

function createLiquibasePropertiesFile (){
    echo "
    changeLogFile: database/db.changelog-master.xml
    driver: org.postgresql.Driver
    url: jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_DATABASE_NAME
    username: $DB_USER
    password: $DB_PASSWORD
    defaultSchemaName: public" > $CWD/liquibase.properties
}

CWD=$(pwd)
if [[ -z $FROM_DOCKER ]];
then
  source $CWD/db_config.sh
  DB_VERSION_TO_ROLLBACK=${1}
fi

if [ -z $DB_HOST ] || [ -z $DB_PORT ] || [ -z $DB_USER ] || [ -z $DB_PASSWORD ] || [ -z $DB_DATABASE_NAME ];
then
    showUsage
    exit 1
fi

showParameters

profileEnviroment=${DEPLOY_PROFILE,,}

if [ -z "$DB_VERSION_TO_ROLLBACK" ]
then
    echo "!!! Please enter the rollback version you would like to return (./rollbackDataBase.sh [DB_VERSION_TO_ROLLBACK]) !!!"
else
    echo "Rolling back the database to version [$DB_VERSION_TO_ROLLBACK]"
    createLiquibasePropertiesFile
    $CWD/liquibase --headless='true' rollback $DB_VERSION_TO_ROLLBACK -Dprofile=$profileEnviroment -Ddbname=$DB_DATABASE_NAME #--log-level DEBUG
fi
