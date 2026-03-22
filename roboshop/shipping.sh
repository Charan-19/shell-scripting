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

dnf install maven -y &>>$LOG_FILE
VALIDATE $? "Installing maven"

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

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip
VALIDATE $? "Downloading shipping code"

rm -rf /app/*
cd /app

unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "Extracting shipping code"
 
mvn clean package &>>$LOG_FILE
VALIDATE $? "Installing shipping dependencies"

mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE
VALIDATE $? "Renaming shipping jar file"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service &>>$LOG_FILE
VALIDATE $? "Copying shipping service file"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading systemd"

systemctl enable shipping 
systemctl start shipping &>>$LOG_FILE
VALIDATE $? "Starting shipping service"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing mysql client"

mysql -h mysql.sachade.shop -uroot -p$MYSQL_ROOT_PASSWORD -e 'use cities' &>>$LOG_FILE

if [ $? -ne 0 ]
then
    echo "Creating cities database and loading data" | tee -a $LOG_FILE
    mysql -h mysql.sachade.shop -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/schema.sql &>>$LOG_FILE
    mysql -h mysql.sachade.shop -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/app-user.sql &>>$LOG_FILE
    mysql -h mysql.sachade.shop -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/master-data.sql &>>$LOG_FILE
    VALIDATE $? "Creating cities database and loading data"
else
    echo -e "Cities database already exists... $Y skipping $N" | tee -a $LOG_FILE
fi  

systemctl restart shipping
VALIDATE $? "Restarting shipping service"

END_TIME=$(date +%s)
EXECUTION_TIME=$(($END_TIME - $START_TIME))
echo -e "Script execution completed successfully and $Y time taken: $EXECUTION_TIME seconds $N" | tee -a $LOG_FILE