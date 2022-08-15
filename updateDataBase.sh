#!/bin/bash

function showUsage() {
  echo
  echo Usage: "Edit file db_config with Data Base infos and execute ./updateDataBase.sh"
  echo
}

function showParameters() {
  echo
  echo "********** Parameters ***********"
  echo
  echo    "DB_HOST: ${DB_HOST}"
  echo    "DB_PORT: ${DB_PORT}"
  echo    "DB_USER: ${DB_USER}"
  echo    "DB_PASSWORD: *******"
  echo    "DB_DATABASE_NAME: ${DB_DATABASE_NAME}"
  echo    "DEPLOY_PROFILE: ${DEPLOY_PROFILE}"
  echo
  echo "*********************************"
  echo
}

function createDataBaseIfNotExists() {
  CURRENT_DB_VERSION=$(psql -q -t -h $DB_HOST -U $DB_USER -p ${DB_PORT} -c "SELECT 1 FROM pg_database WHERE datname = '$DB_DATABASE_NAME';" | xargs)
  echo "CURRENT_DB_VERSION=$CURRENT_DB_VERSION"
  if [[ -z $CURRENT_DB_VERSION ]];
  then
    createdb -E UTF8 -h $DB_HOST -U $DB_USER -p ${DB_PORT} $DB_DATABASE_NAME
    if [ $? -ne 0 ]
    then
      echo ERROR! Could not create database. ABORTING
      exit 1
    fi
  fi
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
fi

if [ -z $DB_HOST ] || [ -z $DB_PORT ] || [ -z $DB_USER ] || [ -z $DB_PASSWORD ] || [ -z $DB_DATABASE_NAME ] || [ -z $DEPLOY_PROFILE ];
then
    showUsage
    exit 1
fi

export PGPASSWORD=$DB_PASSWORD;

showParameters

createLiquibasePropertiesFile

createDataBaseIfNotExists

profileEnviroment=${DEPLOY_PROFILE,,}

$CWD/liquibase --headless='true' update -Dprofile=$profileEnviroment -Ddbname=$DB_DATABASE_NAME #--log-level DEBUG
