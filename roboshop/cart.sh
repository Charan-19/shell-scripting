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

dnf module disable nodejs -y &>>$LOG_FILE
$VALIDATE $? "Disabling nodejs module"


dnf module enable nodejs:20 -y &>>$LOG_FILE
$VALIDATE $? "Enabling nodejs module"

dnf install nodejs -y &>>$LOG_FILE
$VALIDATE $? "Installing nodejs"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "Roboshop user already exits... $Y skipping $N"
fi

mkdir -p /app
$VALIDATE $? "Creating app directory"

curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip
$VALIDATE $? "Downloading cart code"

rm -rf /app/*
cd /app

unzip /tmp/cart.zip &>>$LOG_FILE
$VALIDATE $? "Extracting cart code"
 
npm install &>>$LOG_FILE
$VALIDATE $? "Installing cart dependencies"

cp $SCRIPT_DIR/cart.service /etc/systemd/system/cart.service &>>$LOG_FILE
$VALIDATE $? "Copying cart service file"

systemctl daemon-reload &>>$LOG_FILE
$VALIDATE $? "Reloading systemd"

systemctl enable cart 
systemctl start cart &>>$LOG_FILE
$VALIDATE $? "Starting cart service"

END_TIME=$(date +%s)
EXECUTION_TIME=$(($END_TIME - $START_TIME))
echo -e "Script execution completed successfully and $Y time taken: $EXECUTION_TIME seconds $N" | tee -a $LOG_FILE