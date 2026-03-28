#!/bin/bash
AMI_ID="ami-0220d79f3f480ecf5"
SECURITY_GROUP_ID="sg-0da12a545f9ea850a"
HOSTED_ZONE_ID="Z10343403HZ2PB1IVOET0"
DOMAIN_NAME="sachade.shop"

if [ $# -eq 0 ]
then
    echo "Error: Please provide atleast one instance name as argument"
    exit 1
else
    echo "Creating EC2 instances for $@"
fi


for INSTANCE in $@
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id ${AMI_ID}  --instance-type t3.micro --security-group-ids sg-0da12a545f9ea850a --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE}}]" --query "Instances[0].InstanceId" --output text)

    if [ ${INSTANCE} != "frontend" ]
    then
        IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        RECORD_NAME="$INSTANCE.$DOMAIN_NAME"
        echo -e "Record name for ${INSTANCE} is $RECORD_NAME"
    else
        IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        RECORD_NAME="$DOMAIN_NAME"
        echo -e "Record name for frontend is $RECORD_NAME"
    fi
    echo "${INSTANCE} Ip Address: ${IP}"
    aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch '{
        "Comment": "for catalogue record",
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$RECORD_NAME'",
                "Type": "A",
                "TTL": 1,
                "ResourceRecords": [
                    {"Value": "'${IP}'"}
                ]
            }
        }]
    }'
done

