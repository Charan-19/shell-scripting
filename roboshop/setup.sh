#!/bin/bash
AMI_ID="ami-0220d79f3f480ecf5"
SECURITY_GROUP_ID="sg-0da12a545f9ea850a"
INSTANCES=("frontned","catalogue","user","cart","shipping","payment","dispatch","mongodb","redis","rabbitmq","mysql")

for INSTANCE in ${INSTANCES[@]};
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id ${AMI_ID} --count 2 --instance-type t3.micro --security-group-ids ${SECURITY_GROUP_ID} --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE}}]' --query "Instances[0].InstanceId" --output text)
    if [ ${INSTANCE} != "frontend" ];
    then
        IP= $(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
    else
        IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    fi
    echo "${INSTANCE} Ip Address: ${IP}"

done