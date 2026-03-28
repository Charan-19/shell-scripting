#!/bin/bash
USER_ID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
SOURCE_DIR=$1
DEST_DIR=$2
DAYS=${$3:-7}
log_folder="/var/log/shell-scripts-logs"
SCRIPT_NAME=$(echo $0 | cut -d '.' -f1)
LOG_FILE=$"$log_folder/$SCRIPT_NAME.log"                                                        

VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is .... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is .... $R FAILED $N" | tee -a $LOG_FILE
        exit 1
    fi
}

check_root(){
    if [ $USER_ID -ne 0 ]
    then
        echo -e "$R Error: Please run this script with root user $N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$G Running this script with root user $N" | tee -a $LOG_FILE
    fi
}

check_root
mkdir -p $log_folder

USAGE(){
    echo -e "$R Usage: $N $0 <source_directory> <destination_directory> [days]" | tee -a $LOG_FILE
}

if [ $# -lt 2 ]
then
    USAGE
    exit 1
fi

if [ ! -d $SOURCE_DIR ]
then
    echo -e "$R Error: source directory $SOURCE_DIR does not exist $N" | tee -a $LOG_FILE
    exit 1
fi

if [ ! -d $DEST_DIR ]
then
    echo -e "$R Error: destination directory $DEST_DIR does not exist $N" | tee -a $LOG_FILE
    exit 1
fi

FILES=$(find $SOURCE_DIR -name "*.log" -mtime +$DAYS)

if [ -z "$FILES" ]
then
    echo -e "Files to zip are: $FILES"
    TIMESTAMP=$(date +%F-%H-%M-%S)
    ZIP_FILE="$DEST_DIR/app-logs-$TIMESTAMP.zip"
    find $SOURCE_DIR -name "*.log" -mtime +$DAYS | zip -@ $ZIP_FILE

    if [ -f $ZIP_FILE ]
    then
        echo -e "$G Log files zipped successfully to $ZIP_FILE $N" | tee -a $LOG_FILE
        while IFS= read -r filepath
        do
            rm -rf $filepath
            VALIDATE $? "Deleting old log file $filepath"
        done <<< "$FILES"
        echo -e "$G Old log files deleted successfully $N" | tee -a $LOG_FILE
    else
        echo -e "$R Error: Failed to zip log files $N" | tee -a $LOG_FILE
        exit 1
    fi
else
    echo -e "$Y No log files found to zip $N" | tee -a $LOG_FILE
fi