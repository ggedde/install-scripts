#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DEBUG=0  #  0 = None, 1 = Errors Only, 2 = All

if [ "$2" != "" ]
then
	DEBUG=$2
fi

if [ $DEBUG == 0 ]
then
	Q_DBG="-q"
elif [ $DEBUG == 1 ]
then
	Q_DBG="-q"
elif [ $DEBUG == 2 ]
then
	Q_DBG=""
fi

validate_url() {
  if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
    return 0
  else
    return 1
  fi
}

error() {
    echo "."
	echo $1
	kill "$!" # kill the spinner
	wait $! 2>/dev/null
	exit
}

spinner() {
    local i sp n
    sp='/-\|'
    n=${#sp}
    while sleep 0.1; do
        printf "%s\b\r" "[${sp:i++%n:1}]"
    done
}

spinner & # start the spinner

MYSQL_VERSION=$1
if [ "$MYSQL_VERSION" == "" ]
then
    echo 'No MYSQL Version Specified'
    exit
fi

MYSQL_MAIN=${MYSQL_VERSION:0:3}

BOOST_CONFIG=''

MYSQL_INSTALL_PATH="/opt/mysql/$MYSQL_VERSION"

MYSQL_INIT_SCRIPT="mysqld-$MYSQL_VERSION"

if [ -d "$MYSQL_INSTALL_PATH" ]
then
	echo 'That MYSQL Version already exists'
    exit
fi

# Install mysql user
if id -u mysql ; then
    echo "mysql user exists"
else
    echo "Installing Mysql User"
	groupadd mysql
	useradd -r -g mysql -s /bin/false mysql
fi

MYSQL_USER_EXISTS=$(id -u mysql)
if [ $? -ne 0 ]
then
	echo "Installing Mysql User"
	groupadd mysql
	useradd -r -g mysql -s /bin/false mysql
fi

# Install Dependencies 
echo "
####################################
Installing Dependencies
####################################
"
echo " - Downloading and Installing Packages..."
DEP1=$(apt-get install -y cmake libncurses5-dev build-essential libaio1)
if [ $? -ne 0 ]
then
	echo "${DEP1}"
	error "ERROR: Installing Dependencies"
fi
echo " - Dependencies Installed Successfully!"

if [ ! -f "/opt/source/mysql-${MYSQL_VERSION}.tar.gz" ]
then
	echo ""
	echo "Downloading MYSQL Installation File... "

	if validate_url "https://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAIN}/mysql-boost-${MYSQL_VERSION}.tar.gz"
	then
		$(wget -c $Q_DBG https://dev.mysql.com/get/Downloads/MySQL-${MYSQL_MAIN}/mysql-boost-${MYSQL_VERSION}.tar.gz -O /opt/source/mysql-${MYSQL_VERSION}.tar.gz)
		BOOST_CONFIG='-DDOWNLOAD_BOOST=1 -DWITH_BOOST=/opt/source/boost'

	elif validate_url "http://cdn.mysql.com/Downloads/MySQL-${MYSQL_MAIN}/mysql-${MYSQL_VERSION}.tar.gz"
	then
		$(wget -c $Q_DBG http://cdn.mysql.com/Downloads/MySQL-${MYSQL_MAIN}/mysql-${MYSQL_VERSION}.tar.gz -O /opt/source/mysql-${MYSQL_VERSION}.tar.gz)

	elif validate_url "http://cdn.mysql.com/archives/mysql-${MYSQL_MAIN}/mysql-${MYSQL_VERSION}.tar.gz"
	then
		$(wget -c $Q_DBG http://cdn.mysql.com/archives/mysql-${MYSQL_MAIN}/mysql-${MYSQL_VERSION}.tar.gz -O /opt/source/mysql-${MYSQL_VERSION}.tar.gz)
	fi
fi

if [ ! -f "/opt/source/mysql-$MYSQL_VERSION.tar.gz" ]
then
	error "Error: Downloading MYSQL Installation File (http://cdn.mysql.com/archives/mysql-${MYSQL_MAIN}/mysql-${MYSQL_VERSION}.tar.gz)"
fi

if [ ! -d "/opt/source/mysql-${MYSQL_VERSION}" ]
then
	echo " - Extracting File..."
    TAR=$(tar zxvf /opt/source/mysql-$MYSQL_VERSION.tar.gz -C /opt/source)
    if [ $? -ne 0 ]
	then
		echo "${TAR}"
		error "ERROR: Extracting File!"
	fi
fi

if [ ! -d "/opt/source/mysql-${MYSQL_VERSION}/bld" ]
then
	$(mkdir /opt/source/mysql-${MYSQL_VERSION}/bld)
fi

cd /opt/source/mysql-${MYSQL_VERSION}/bld

echo " - Running Cmake..."
CMAKE=$(cmake .. -DCMAKE_INSTALL_PREFIX="${MYSQL_INSTALL_PATH}" -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DENABLED_LOCAL_INFILE=1 -DWITH_ZLIB=bundled -DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 ${BOOST_CONFIG})
if [ $? -ne 0 ]
then
	echo "${CMAKE}"
	error "ERROR: Cmake Failed!"
fi
echo " - Cmake Complete!"

echo " - Running Make... (This may take awhile)"
if [ $DEBUG == 0 ]
then
	MAKE=$(make -s &>/dev/null)
elif [ $DEBUG == 1 ]
then
	MAKE=$(make 1>/dev/null)
elif [ $DEBUG == 2 ]
then
	MAKE=$(make)
fi
if [ $? -ne 0 ]
then
	echo "${MAKE}"
	error "ERROR: Make Failed!"
fi
echo " - Make Complete!"

echo " - Running Make Install..."

if [ $DEBUG == 0 ]
then
	MAKEINSTALL=$(make install -s &>/dev/null)
elif [ $DEBUG == 1 ]
then
	MAKEINSTALL=$(make install 1>/dev/null)
elif [ $DEBUG == 2 ]
then
	MAKEINSTALL=$(make install)
fi

if [ $? -ne 0 ]
then
	echo "${MAKEINSTALL}"
	error "ERROR: Make Failed!"
fi

if [ ! -d "${MYSQL_INSTALL_PATH}" ]
then
	error "Error installing MYSQL"
fi

cd ${MYSQL_INSTALL_PATH}

echo " - Install Complete!"
echo "
####################################
Configuring MYSQL ${MYSQL_VERSION}
####################################
"

if [ ! -d "/run/mysql" ]
then
	$(mkdir /run/mysql)
	$(chown mysql:adm /run/mysql)
fi

if [ ! -f "/etc/init.d/${MYSQL_INIT_SCRIPT}" ]
then
	echo " - Creating MYSQL Startup File"
	$(cp ${MYSQL_INSTALL_PATH}/support-files/mysql.server /etc/init.d/${MYSQL_INIT_SCRIPT})
	$(chmod +x /etc/init.d/${MYSQL_INIT_SCRIPT})
	$(sed -i -e "s/# Provides: mysql/# Provides: ${MYSQL_INIT_SCRIPT}/g" /etc/init.d/${MYSQL_INIT_SCRIPT})
	$(update-rc.d ${MYSQL_INIT_SCRIPT} defaults)
fi

if [ ! -f "${MYSQL_INSTALL_PATH}/my.cnf" ] && [ "$MYSQL_MAIN" == "5.5" ]
then
	echo "[client]
port 					= 0
socket 					= /run/mysql/mysqld-${MYSQL_VERSION}.sock

[mysqld]
user            		= mysql
port            		= 0
bind-address            = 127.0.0.1
pid-file        		= /run/mysql/mysqld-${MYSQL_VERSION}.pid
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
basedir         		= ${MYSQL_INSTALL_PATH}
datadir         		= ${MYSQL_INSTALL_PATH}/data
tmpdir          		= /tmp
lc-messages-dir 		= ${MYSQL_INSTALL_PATH}/share
general_log_file 		= /var/log/mysql/mysql-${MYSQL_VERSION}.log
log_error 				= /var/log/mysql/mysql-${MYSQL_VERSION}_error.log
slow_query_log_file		= /var/log/mysql/mysql-${MYSQL_VERSION}_slow.log
skip-external-locking
skip-networking

key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

" > ${MYSQL_INSTALL_PATH}/my.cnf
fi

if [ ! -f "$MYSQL_INSTALL_PATH/my.cnf" ] && [ "$MYSQL_MAIN" == "5.6" ]
then
	echo "[mysqld]

user            		= mysql
port            		= 0
bind-address            = 127.0.0.1
pid-file        		= /run/mysql/mysqld-${MYSQL_VERSION}.pid
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
basedir         		= ${MYSQL_INSTALL_PATH}
datadir         		= ${MYSQL_INSTALL_PATH}/data
tmpdir          		= /tmp
lc-messages-dir 		= ${MYSQL_INSTALL_PATH}/share
general_log_file 		= /var/log/mysql/mysql-${MYSQL_VERSION}.log
log_error 				= /var/log/mysql/mysql-${MYSQL_VERSION}_error.log
slow_query_log_file		= /var/log/mysql/mysql-${MYSQL_VERSION}_slow.log
skip-external-locking
skip-networking

sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

[mysqld_safe]
syslog	

[mysqldump]
quick
quote-names
max_allowed_packet      = 16M

" > ${MYSQL_INSTALL_PATH}/my.cnf
fi

if [ ! -f "$MYSQL_INSTALL_PATH/my.cnf" ] && [ "$MYSQL_MAIN" == "5.7" ]
then
	echo "[mysqld_safe]
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
nice            		= 0

[mysqld]
user            		= mysql
port            		= 0
bind-address				= 127.0.0.1
pid-file        		= /run/mysql/mysqld-${MYSQL_VERSION}.pid
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
basedir         		= ${MYSQL_INSTALL_PATH}
datadir         		= ${MYSQL_INSTALL_PATH}/data
tmpdir          		= /tmp
lc-messages-dir 		= ${MYSQL_INSTALL_PATH}/share
general_log_file 		= /var/log/mysql/mysql-${MYSQL_VERSION}.log
log_error 					= /var/log/mysql/mysql-${MYSQL_VERSION}_error.log
slow_query_log_file		= /var/log/mysql/mysql-${MYSQL_VERSION}_slow.log
skip-external-locking
skip-networking

key_buffer_size         = 16M
max_allowed_packet      = 16M
thread_stack            = 192K
thread_cache_size       = 8
myisam-recover-options  = BACKUP
query_cache_limit       = 1M
query_cache_size        = 16M

expire_logs_days        = 10
max_binlog_size   		= 100M

" > ${MYSQL_INSTALL_PATH}/my.cnf
fi

if [ ! -f "$MYSQL_INSTALL_PATH/my.cnf" ] && [ "$MYSQL_MAIN" == "8.0" ]
then
	echo "[mysqld_safe]
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
nice            		= 0

[mysqld]
user            		= mysql
port            		= 0
bind-address				= 127.0.0.1
pid-file        		= /run/mysql/mysqld-${MYSQL_VERSION}.pid
socket          		= /run/mysql/mysqld-${MYSQL_VERSION}.sock
basedir         		= ${MYSQL_INSTALL_PATH}
datadir         		= ${MYSQL_INSTALL_PATH}/data
tmpdir          		= /tmp
lc-messages-dir 		= ${MYSQL_INSTALL_PATH}/share
general_log_file 		= /var/log/mysql/mysql-${MYSQL_VERSION}.log
log_error 					= /var/log/mysql/mysql-${MYSQL_VERSION}_error.log
slow_query_log_file		= /var/log/mysql/mysql-${MYSQL_VERSION}_slow.log
skip-external-locking
skip-networking

" > ${MYSQL_INSTALL_PATH}/my.cnf
fi

if [ ! -d "${MYSQL_INSTALL_PATH}/data" ]
then
	$(mkdir ${MYSQL_INSTALL_PATH}/data)
	$(chown -R mysql:mysql ${MYSQL_INSTALL_PATH}/data)
fi

cd ${MYSQL_INSTALL_PATH}

if [ "$MYSQL_MAIN" == "5.5" ] || [ "$MYSQL_MAIN" == "5.6" ]
then
	$(chown -R mysql:mysql .)
	$(scripts/mysql_install_db --defaults-file=${MYSQL_INSTALL_PATH}/my.cnf --user=mysql)
	$(chown -R root .)
	$(chown -R mysql:mysql data)
fi

if [[ $MYSQL_MAIN > 5.6 ]]
then
	$(chmod 750 data)
	$(bin/mysqld --defaults-file=${MYSQL_INSTALL_PATH}/my.cnf --initialize-insecure --user=mysql)
	$(bin/mysql_ssl_rsa_setup --datadir=${MYSQL_INSTALL_PATH}/data --uid=mysql)
fi

echo ""
if [ -d "/opt/source/mysql-${MYSQL_VERSION}" ]
then
	echo "Removing Build Folder"
	$(rm -rf /opt/source/mysql-${MYSQL_VERSION})
fi

if [ -d "/opt/source/mysql-${MYSQL_VERSION}.tar.gz" ]
then
	echo "Deleting Source File"
	$(rm /opt/source/mysql-${MYSQL_VERSION}.tar.gz)
fi

kill "$!" # kill the spinner
wait $! 2>/dev/null

echo ""
echo "
#############################################################

Success!
MYSQL Version $MYSQL_VERSION was installed Successfully!

#############################################################
"

${MYSQL_INSTALL_PATH}/bin/mysql --version

echo "
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

MYSQL Location:         $MYSQL_INSTALL_PATH
MYSQL Binary:           $MYSQL_INSTALL_PATH/bin/mysql
MYSQL Version Test:     $MYSQL_INSTALL_PATH/bin/mysql --version

Start MYSQL $MYSQL_VERSION:            sudo service $MYSQL_INIT_SCRIPT start

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
"
