#!/bin/bash

PHP_VERSION=$1

if [ "$PHP_VERSION" == "" ]
then
        echo 'No PHP Version Specified'
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

if [ -f "/etc/init.d/php-fpm-${PHP_VERSION}" ]
then
	echo "Stopping PHP if running"
	$(service php-fpm-${PHP_VERSION} stop)

	echo "Deleting Startup File"
	$(rm -f /etc/init.d/php-fpm-${PHP_VERSION})
fi

if [ -d "/opt/source/php-${PHP_VERSION}" ]
then
	echo "Deleting Source Directory"
	$(rm -rf /opt/source/php-${PHP_VERSION})
fi

if [ -d "/opt/php/${PHP_VERSION}" ]
then
	echo "Deleting Installation Directory"
	$(rm -rf /opt/php/${PHP_VERSION})
fi

if [ -f "/run/php-fpm-${PHP_VERSION}_default.sock" ]
then
	echo "Deleting PHP Socket File"
	$(rm -f /run/php-fpm-${PHP_VERSION}_default.sock)
fi

kill "$!" # kill the spinner
	wait $! 2>/dev/null

echo "."
echo  "Completed!"
