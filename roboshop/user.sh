#!/bin/bash

USERID=$(id -u)
START_TIME=$(date +%S)
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
VALIDATE $? "Disabling nodejs module"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling nodejs:20 module"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing nodejs:20"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "Roboshop user already exits... $Y skipping $N"
fi

mkdir -p /app
VALIDATE $? "Creating app directory"

cd /app

rm -rf /app/* &>>$LOG_FILE
VALIDATE $? "Cleaning old app content"

curl -L -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip
VALIDATE $? "Downloading user code"

unzip /tmp/user.zip
VALIDATE $? "Extracting user code"

npm install &>>$LOG_FILE
VALIDATE $? "Installing user dependencies"

cp $SCRIPT_DIR/user.service /etc/systemd/system/user.service
VALIDATE $? "Copying user service file"

systemctl daemon-reload
VALIDATE $? "Reloading systemd"
systemctl enable user &>>$LOG_FILE
VALIDATE $? "Enabling user service"
systemctl start user &>>$LOG_FILE
VALIDATE $? "Starting user service"

END_TIME=$(date +%s)
EXECUTION_TIME=$(($END_TIME - $START_TIME))
echo -e "Script execution completed successfully and $Y time taken: $EXECUTION_TIME seconds $N" | tee -a $LOG_FILE
