#!/bin/bash

MYSQL_VERSION=$1

if [ "$MYSQL_VERSION" == "" ]
then
        echo 'No MYSQL Version Specified'
        exit
fi

spinner() {
    local i sp n
    sp='/-\|'
    n=${#sp}
    while sleep 0.1; do
        printf "%s\b\r" "[${sp:i++%n:1}]"
    done
}

spinner & # start the spinner

if [ -f "/etc/init.d/mysqld-${MYSQL_VERSION}" ]
then
	echo "Stopping MYSQL if running"
	$(service mysqld-${MYSQL_VERSION} stop)

	echo "Deleting Startup File"
	$(rm -f /etc/init.d/mysqld-${MYSQL_VERSION})
fi

if [ -d "/opt/mysql/${MYSQL_VERSION}" ]
then
	echo "Deleting Installation Directory"
	$(rm -rf /opt/mysql/${MYSQL_VERSION})
fi

if [ -d "/opt/source/mysql-${MYSQL_VERSION}" ]
then
	echo "Deleting Source Directory"
	$(rm -rf /opt/source/mysql-${MYSQL_VERSION})
fi

if [ -d "/opt/source/mysql-${MYSQL_VERSION}.tar.gz" ]
then
	echo "Deleting Source File"
	$(rm /opt/source/mysql-${MYSQL_VERSION}.tar.gz)
fi

if [ -f "/run/mysql/mysqld-${MYSQL_VERSION}.sock" ]
then
	echo "Deleting MYSQL Socket File"
	$(rm -f /run/mysql/mysqld-${MYSQL_VERSION}.sock)
fi

if [ -f "/run/mysql/mysqld-${MYSQL_VERSION}.pid" ]
then
	echo "Deleting MYSQL PID File"
	$(rm -f /run/mysql/mysqld-${MYSQL_VERSION}.pid)
fi

kill "$!" # kill the spinner
	wait $! 2>/dev/null

echo "."
echo  "Completed!"
