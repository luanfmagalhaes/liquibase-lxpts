FROM eclipse-temurin:11

WORKDIR /liquibase

COPY . /liquibase

ENV DB_HOST=$DB_HOST
ENV DB_PORT=$DB_PORT
ENV DB_DATABASE_NAME=$DB_DATABASE_NAME
ENV DB_USER=$DB_USER
ENV DB_PASSWORD=$DB_PASSWORD
ENV DEPLOY_PROFILE=$DEPLOY_PROFILE
ENV TYPE_OPERATION=$TYPE_OPERATION
ENV DB_VERSION_TO_ROLLBACK=$DB_VERSION_TO_ROLLBACK

RUN apt update
RUN apt install postgresql-client -y
RUN chmod -R 777 /liquibase

CMD ["/bin/bash", "-c", "./${TYPE_OPERATION}DataBase.sh" ]
