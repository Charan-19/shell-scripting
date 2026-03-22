#!/bin/bash

USERID=$(id -u)
START_TIME=$(date +%s)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d '.' -f1)
LOG_FILE=$"$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

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
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is .... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is .... $R FAILED $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf module disable redis -y &>>$LOG_FILE
VALIDATE $? "Disabling redis module"

dnf module enable redis:7 -y &>>$LOG_FILE
VALIDATE $? "Enabling redis:7 module"

dnf install redis -y &>>$LOG_FILE
VALIDATE $? "Installing redis"

sed -i  's/127.0.0.1/0.0.0.0/g' -i  '/protected-mode/ c protected-mode no' /etc/redis/redis.conf
VALIDATE $? "Editing redis conf file for remote connections"

systemctl enable redis
systemctl start redis &>>$LOG_FILE
VALIDATE $? "Starting redis"

END_TIME=$(date +%s)
EXECUTION_TIME=$(($END_TIME - $START_TIME))
echo -e "Script execution completed successfully and $Y time taken: $EXECUTION_TIME seconds $N" | tee -a $LOG_FILE
