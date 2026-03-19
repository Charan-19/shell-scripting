#!/bin/bash

USERID=$(id -u)

if [ $USERID -ne 0 ]
   then
        echo "ERROR: Run this script with root user"
        exit 1

else
        echo "Running this script with root user"
fi

dnf list installed mysql

if [ $? -ne 0 ]
   then
        echo "mysql is not installed... going to install it"
        dnf install mysql -y
        if [ $? -eq 0 ]
           then
                echo "mysql installation..... success"

        else
                echo "mysql installation.... failed"
                exit 1

        fi
else
        echo "mysql is already installed.... nothing to do"
fi