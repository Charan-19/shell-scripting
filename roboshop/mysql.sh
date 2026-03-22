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

echo "Please enter your MYSQL root password"
read -s MYSQL_ROOT_PASSWORD

VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is .... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is .... $R FAILED $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf install mysql-server -y &>>LOG_FILE
VALIDATE $? "Installing mysql-server"

systemctl enable mysqld 
VALIDATE $? "Enabling mysqld"
systemctl start mysqld
VALIDATE $? "Starting mysqld"

mysql_secure_installation --set-root-pass $MYSQL_ROOT_PASSWORD &>>LOG_FILE
VALIDATE $? "Setting root password"

END_TIME=$(date +%s)
EXECUTION_TIME=$(($END_TIME - $START_TIME))
echo -e "Script execution completed successfully and $Y time taken: $EXECUTION_TIME seconds $N" | tee -a $LOG_FILE