#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d '.' -f1)
LOG_FILE=$"$LOGS_FOLDER/$SCRIPT_NAME.log"

mkdir -p $LOGS_FOLDER
echo "Script execution started at $(date)" | tee -a $LOG_FILE

if [ $USERID -ne 0 ]
then
    echo -e "$R Error: please run this script with root user $N" | tee -a $LOG_FILE
    exit 1
else
    echo "Running this script with root user" | tee -a $LOG_FILE
fi

VALIDATE(){
    if [ $1 -eq 0]
    then
        echo -e "$2 is .... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is .... $R FAILED $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling nodejs module"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling nodejs:20 module"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing nodejs:20"

id roboshop
if[ $? -ne 0]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "Roboshop user already exits... $Y skipping $N"
fi

mkdir -p /app
VALIDATE $? "Creating app directory"


curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip
VALIDATE $? "Downloading catalogue code"

rm -f /app/*
cd /app 
unzip /tmp/catalogue.zip
VALIDATE $? "Extracting catalogue code"

npm install &>>$LOG_FILE
VALIDATE $? "Installing nodejs dependencies"

cp $PWD/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? "Copying catalogue service file"

systemctl dameon-reload &>>$LOG_FILE

systemctl enable catalogue &>>$LOG_FILE

systemctl start catalogue
VALIDATE $? "Starting catalogue service"

cp $PWD/mongo.repo /etc/yum.repos.d/mongodb.repo
VALIDATE $? "Copying MongoDB repo file"

dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "Installing MongoDB client"

status=$(mongosh --host mongodb.sachade.shop </app/db/master-data.js eval 'db.getMongo().getDBNames().indexOf("catalogue")')

if [ $status -lt 0 ]
then
    mongosh --host mongodb.sachade.shop </app/db/master-data.js
    $VALIDATE $? "Loading catalogue data to MongoDB" 
else
    echo -e "Catalogue data is already loaded... $Y skipping $N"
fi