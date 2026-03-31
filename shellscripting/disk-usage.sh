#!/bin/bash

DISK_USAGE=$(df -hT | grep -v Filesystem)
DISK_THRESHOLD=5
MSG=""
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

while IFS= read line
do
    USAGE=$(echo $line | awk '{print $6F}' | cut -d '%' -f1)
    PARTITION=$(echo $line | awk '{print $7}')
    if [ $USAGE -gt $DISK_THRESHOLD ]
    then
        MSG+="Disk usage on partition $PARTITION is at $USAGE% on server with IP $IP <br>"
    fi

done <<< $DISK_USAGE

sh mails.sh "SRE Team" "Disk Usage Alert" "$IP" "$MSG" "saicharan1718@gmail.com" "High Disk Usage Alert on $IP"