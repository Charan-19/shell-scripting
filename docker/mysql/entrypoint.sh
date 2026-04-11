#!/bin/bash

if [ -f /tmp/mysql_root_password.txt ]; then
    PASSWORD=$(cat /tmp/mysql_root_password.txt)
    echo "Accessed Root password"
else
    echo "Password file not found"
    exit 1
fi
# Making it as available in env
export MYSQL_ROOT_PASSWORD=$PASSWORD
rm -rf /tmp/mysql_root_password.txt
exec /entrypoint.sh mysqld