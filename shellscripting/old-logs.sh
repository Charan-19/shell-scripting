#!/bin/bash
USER_ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
SOURCE_DIR="/var/log/roboshop-logs"
log_folder="/var/log/shell-scripts-logs"
SCRIPT_NAME=$(echo $0 | cut -d '.' -f1)
LOG_FILE=$"$log_folder/$SCRIPT_NAME.log"                                                        

mkdir -p $log_folder

if [ $USER_ID -ne 0 ]
then
    echo -e "$R Error: Please run this script with root user $N" | tee -a $LOG_FILE
    exit 1
else
    echo -e "$G Running this script with root user $N" | tee -a $LOG_FILE
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


files_to_delete=$(find $SOURCE_DIR -name "*.log" -mmin +5)
VALIDATE $? "Finding log files older than 5 minutes in $SOURCE_DIR"

while IFS= read -r filepath
do
    rm -rf $filepath
    VALIDATE $? "Deleting old log file $filepath"
done <<< $files_to_delete

