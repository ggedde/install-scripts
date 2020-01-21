#!/bin/bash

DEBUG=0  #  0 = None, 1 = Errors Only, 2 = All

if [ "$2" != "" ]
then
	DEBUG=$2
fi

PHP_VERSION=$1

if [ "$PHP_VERSION" == "" ]
then
    echo 'No PHP Version Specified'
    exit
fi

PHP_INSTALL_PATH="/opt/php/$PHP_VERSION"
if [ "$3" != "" ]
then
	PHP_INSTALL_PATH=$3
fi

PHP_INIT_SCRIPT="php$PHP_VERSION-fpm"
if [ "$4" != "" ]
then
	PHP_INIT_SCRIPT=$4
fi

PHP_MAIN=${PHP_VERSION:0:3}

PHP_WITH_MYSQL=""
PHP_WITH_MCRYPT=""
PHP_WITH_GD_NATIVE_TTF=""
PHP_WITH_LIBZIP=""

# Add Edditional PHP Extensions
PHP_EXTENSIONS=()

# Bash is bad at comparing decimals
if [[ $PHP_MAIN > 7.2 ]] || [ "$PHP_MAIN" == "7.2" ]
then
	PHP_WITH_LIBZIP="--with-libzip"
	PHP_EXTENSIONS+=("Mcrypt-1.0.2, mcrypt, https://pecl.php.net/get/mcrypt-1.0.2.tgz, mcrypt-1.0.2.tgz, mcrypt-1.0.2, mcrypt.so")
	PHP_EXTENSIONS+=("MemcacheD-3.1.3, memcached, https://pecl.php.net/get/memcached-3.1.3.tgz, memcached-3.1.3.tgz, memcached-3.1.3, memcached.so")
	PHP_EXTENSIONS+=("APCu-5.1.17, apcu, https://pecl.php.net/get/apcu-5.1.17.tgz, apcu-5.1.17.tgz, apcu-5.1.17, apcu.so")
	PHP_EXTENSIONS+=("Redis-3.1.6, redis, https://pecl.php.net/get/redis-3.1.6.tgz, redis-3.1.6.tgz, redis-3.1.6, redis.so")
# Bash is bad at comparing decimals
elif [[ $PHP_MAIN > 7.0 ]] || [ "$PHP_MAIN" == "7.0" ]
then
	PHP_EXTENSIONS+=("MemcacheD-3.0.4, memcached, https://pecl.php.net/get/memcached-3.0.4.tgz, memcached-3.0.4.tgz, memcached-3.0.4, memcached.so")
	PHP_EXTENSIONS+=("APCu-5.1.12, apcu, https://pecl.php.net/get/apcu-5.1.12.tgz, apcu-5.1.12.tgz, apcu-5.1.12, apcu.so")
	PHP_EXTENSIONS+=("Redis-3.0.0, redis, https://pecl.php.net/get/redis-3.0.0.tgz, redis-3.0.0.tgz, redis-3.0.0, redis.so")
else
	PHP_EXTENSIONS+=("MemcacheD-2.2.0, memcached, http://pecl.php.net/get/memcached-2.2.0.tgz, memcached-2.2.0.tgz, memcached-2.2.0, memcached.so")
	PHP_EXTENSIONS+=("Memcache-2.2.6, memcache, http://pecl.php.net/get/memcache-2.2.6.tgz, memcache-2.2.6.tgz, memcache-2.2.6, memcache.so")
	PHP_EXTENSIONS+=("APCu-4.0.11, apcu, https://pecl.php.net/get/apcu-4.0.11.tgz, apcu-4.0.11.tgz, apcu-4.0.11, apcu.so")
	PHP_EXTENSIONS+=("Redis-2.2.8, redis, https://pecl.php.net/get/redis-2.2.8.tgz, redis-2.2.8.tgz, redis-2.2.8, redis.so")
	PHP_WITH_MYSQL="--with-mysql"
fi

if [[ $PHP_MAIN < 7.2 ]]
then
	PHP_WITH_MCRYPT="--with-mcrypt"
fi

if [[ $PHP_MAIN < 7.1 ]]
then
	PHP_WITH_GD_NATIVE_TTF="--enable-gd-native-ttf"
fi

if [[ $PHP_MAIN < 5.5 ]]
then
	PHP_ENABLE_OPCACHE=""
	PHP_EXTENSIONS+=("ZendOpcache-7.0.5, zendopcache, http://pecl.php.net/get/ZendOpcache, ZendOpcache, zendopcache-7.0.5, opcache.so")
else
	PHP_ENABLE_OPCACHE="--enable-opcache"
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

# Install Dependencies 
echo "
####################################
Installing Dependencies
####################################
"
echo " - Downloading and Installing Packages..."
DEP1=$(apt-get install -y autoconf build-essential freetds-dev libapache2-mod-fcgid libbz2-dev libc-client2007e-dev libcurl4-openssl-dev libfcgi-dev libfreetype6-dev libgd-dev libgeoip-dev libjpeg-dev libjpeg-turbo8-dbg libjpeg-turbo8-dev libjpeg8-dev libjpeg9-dbg libjson-c-dev libkrb5-dev libmcrypt-dev libmemcached-dev libmhash-dev libmysqlclient-dev libpcre3-dev libpng-dev libpq-dev libssl-dev libtiff-dev libtiff5-dev libxml2-dev libxpm-dev libxslt1-dev libzip-dev lynx php-curl php-dev php-pear re2c systemtap-sdt-dev unzip)
if [ $? -ne 0 ]
then
	echo "${DEP1}"
	error "ERROR: Installing Dependencies"
fi
echo " - Dependencies Installed Successfully!"

if [ ! -f "/usr/lib/x86_64-linux-gnu/libc-client.a" ]
then
	# Create Symlink for with-imap support
	echo " - Creating Imap link Support"
	IMAPSYMLINK=$(ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a)
	if [ $? -ne 0 ]
	then
		echo "${IMAPSYMLINK}"
		error "ERROR: Creating Imap Symlink"
	fi
fi

if [ ! -f "/usr/include/curl/curl.h" ]
then
	# Create Symlink for curl support
	echo " - Creating Curl link Support"
	CURLSYMLINK=$(ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl)
	if [ $? -ne 0 ]
	then
		echo "${CURLSYMLINK}"
		error "ERROR: Creating Curl Symlink"
	fi
fi

echo " - Checking Source directory"
if [ ! -d '/opt/source' ]
then
	echo " - Creating Source directory - /opt/source"
    mkdir -p /opt/source
fi

PHP_INSTALL_DIR=$(dirname "${PHP_INSTALL_PATH}")
echo " - Checking PHP Location directory"
if [ ! -d $PHP_INSTALL_DIR ]
then
	echo " - Creating PHP Location directory - $PHP_INSTALL_DIR"
    mkdir -p $PHP_INSTALL_DIR
fi

echo "
####################################
Downloading Sources
####################################"

if [ ! -f "/opt/source/php-$PHP_VERSION.tar.bz2" ]
then
	echo ""
	echo "Downloading PHP Installation File... "
	$(wget -c $Q_DBG http://us2.php.net/get/php-$PHP_VERSION.tar.bz2/from/this/mirror -O /opt/source/php-$PHP_VERSION.tar.bz2)
fi

if [ ! -f "/opt/source/php-$PHP_VERSION.tar.bz2" ]
then
	error "Error: Downloading PHP Installation File (http://us2.php.net/get/php-$PHP_VERSION.tar.bz2/from/this/mirror)"
fi

if [ ! -d "/opt/source/php-$PHP_VERSION" ]
then
	echo " - Extracting File..."
    TAR=$(tar xvjf /opt/source/php-$PHP_VERSION.tar.bz2 -C /opt/source)
    if [ $? -ne 0 ]
	then
		echo "${TAR}"
		error "ERROR: Extracting File!"
	fi
fi

if [ ! -d "/opt/source/php-$PHP_VERSION" ]
then
	error "ERROR: Extracting File!"
fi

# Downloading Extensions
IFS=""
for PHP_EXT_ARRAY in ${PHP_EXTENSIONS[@]}; do
	IFS=', ' read -r -a PHP_EXT <<< "${PHP_EXT_ARRAY}"

	EXT_NAME="${PHP_EXT[0]}"
	EXT_SHORT_NAME="${PHP_EXT[1]}"
	EXT_URL="${PHP_EXT[2]}"
	EXT_FILE="${PHP_EXT[3]}"
	EXT_DIR="${PHP_EXT[4]}"
	EXT_MODULE="${PHP_EXT[5]}"

	if [ ! -d "/opt/source/$EXT_DIR" ]
	then

		if [ ! -f "/opt/source/$EXT_FILE" ]
		then
			echo ""
			echo "Downloading Extension: $EXT_NAME... "
			$(wget -c $Q_DBG $EXT_URL -O /opt/source/$EXT_FILE)
		fi

		if [ ! -f "/opt/source/$EXT_FILE" ]
		then
			error "Error Downloading $EXT_NAME (/opt/source/$EXT_URL)"
		fi

		BASENAME=$(basename "$EXT_FILE")
		FILE_EXTENSION="${BASENAME##*.}"

		echo " - Extracting File..."
		if [ "$FILE_EXTENSION" == "zip" ]
		then
			EXT_TAR=$(unzip /opt/source/$EXT_FILE -d /opt/source)
		else
			EXT_TAR=$(tar xvzf /opt/source/$EXT_FILE -C /opt/source)
		fi

	    if [ $? -ne 0 ]
		then
			echo "${EXT_TAR}"
			error "ERROR: Extracting $EXT_NAME File!"
		fi
	fi

	if [ ! -d "/opt/source/$EXT_DIR" ]
	then
		error "ERROR: Extracting $EXT_NAME File!"
	fi

done

echo " - Checking Bison"
if [ ! -f "/usr/local/bin/bison" ]
then
	echo " - Downloading Bison..."
	$(wget -c $Q_DBG https://launchpad.net/bison/head/2.6.4/+download/bison-2.6.4.tar.gz -O /opt/source/bison-2.6.4.tar.gz)

	echo " - Extracting Bison..."
	BISON_TAR=$(tar xvzf /opt/source/bison-2.6.4.tar.gz -C /opt/source)
    if [ $? -ne 0 ]
	then
		echo "${BISON_TAR}"
		error "ERROR: Extracting Bison File!"
	fi

	if [ ! -d "/opt/source/bison-2.6.4" ]
	then
		error "Error: Extracting Bison File..."
	fi

	cd /opt/source/bison-2.6.4/

	if [ $DEBUG == 0 ]
	then
		MAKE_CLEAN=$(make clean -s &>/dev/null)
	elif [ $DEBUG == 1 ]
	then
		MAKE_CLEAN=$(make clean 1>/dev/null)
	elif [ $DEBUG == 2 ]
	then
		MAKE_CLEAN=$(make clean)
	fi
	echo ""
	echo "Installing Bison..."
	echo " - Configuring Bison..."
	BISON_CONFIGURE=$(./configure $Q_DBG)
	if [ $? -ne 0 ]
	then
		echo "${BISON_CONFIGURE}"
		error "ERROR: Configuring Bison"
	fi

	echo " - Running Make..."
	if [ $DEBUG == 0 ]
	then
		BISON_MAKE=$(make -s &>/dev/null)
	elif [ $DEBUG == 1 ]
	then
		BISON_MAKE=$(make 1>/dev/null)
	elif [ $DEBUG == 2 ]
	then
		BISON_MAKE=$(make)
	fi

	if [ $? -ne 0 ]
	then
		echo "${BISON_MAKE}"
		error "ERROR: Make on Bison"
	fi

	echo " - Running Make Install..."
	if [ $DEBUG == 0 ]
	then
		BISON_MAKEINSTALL=$(make install -s &>/dev/null)
	elif [ $DEBUG == 1 ]
	then
		BISON_MAKEINSTALL=$(make install 1>/dev/null)
	elif [ $DEBUG == 2 ]
	then
		BISON_MAKEINSTALL=$(make install)
	fi

	if [ $? -ne 0 ]
	then
		echo "${BISON_MAKEINSTALL}"
		error "ERROR: Make Intall on Bison"
	fi

	echo " - Install Complete!"

	echo " - Adding /usr/local/bin to PATH"
	$(export PATH=\$PATH:/usr/local/bin)
fi

echo "
####################################
Installing PHP $PHP_VERSION
####################################
"

cd /opt/source/php-$PHP_VERSION

echo " - Clearing any previous installations"
if [ $DEBUG == 0 ]
then
	MAKE_CLEAN=$(make clean -s &>/dev/null)
elif [ $DEBUG == 1 ]
then
	MAKE_CLEAN=$(make clean 1>/dev/null)
elif [ $DEBUG == 2 ]
then
	MAKE_CLEAN=$(make clean)
fi

echo " - Running Configure..."
CONFIGURE=$(./configure $Q_DBG --prefix=$PHP_INSTALL_PATH --disable-rpath --enable-bcmath --enable-calendar --enable-dtrace --enable-exif --enable-filter --enable-fpm --enable-hash --enable-inline-optimization --enable-libxml --enable-mbregex --enable-mbstring --enable-pcntl --enable-session --enable-soap --enable-sockets --enable-sysvsem --enable-sysvshm --enable-zip --with-bz2 --with-curl --with-fpm-group=www-data --with-fpm-user=www-data --with-freetype-dir --with-gd --with-gettext --with-imap --with-imap-ssl --with-jpeg-dir=/usr --with-kerberos --with-libdir=/lib/x86_64-linux-gnu --with-libxml-dir=/usr --with-mhash --with-mysqli --with-openssl --with-pcre-regex --with-pdo-mysql --with-pdo-pgsql --with-pgsql --with-png-dir=/usr --with-xmlrpc --with-xsl --with-zlib --with-zlib-dir $PHP_WITH_MCRYPT $PHP_WITH_GD_NATIVE_TTF $PHP_WITH_LIBZIP $PHP_WITH_MYSQL $PHP_ENABLE_OPCACHE)
if [ $? -ne 0 ]
then
	echo "${CONFIGURE}"
	error "ERROR: Configure Failed!"
fi
echo " - Configure Complete!"

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

if [ ! -d "$PHP_INSTALL_PATH" ]
then
	error "ERROR: Make Failed! Did not create folder $PHP_INSTALL_PATH"
fi

echo " - Make Install Complete!"
echo "
####################################
Configuring PHP $PHP_VERSION
####################################
"

if [ ! -d "$PHP_INSTALL_PATH/lib" ]
then
	$(mkdir $PHP_INSTALL_PATH/lib)
fi

if [ ! -f "$PHP_INSTALL_PATH/lib/php.ini" ] && [ -f "/opt/source/php-$PHP_VERSION/php.ini-production" ]
then
	echo " - Creating PHP INI File"
	$(cp /opt/source/php-$PHP_VERSION/php.ini-production $PHP_INSTALL_PATH/lib/php.ini)
fi

if [ ! -f "/etc/init.d/$PHP_INIT_SCRIPT" ]
then
	echo " - Creating PHP Startup File"
	$(cp /opt/source/php-$PHP_VERSION/sapi/fpm/init.d.php-fpm.in /etc/init.d/$PHP_INIT_SCRIPT)
	$(chmod +x /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/# Provides:          php-fpm/# Provides:          $PHP_INIT_SCRIPT/g" /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/\@prefix\@/${PHP_INSTALL_PATH//\//\\\/}/g" /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/\@exec_prefix\@/${PHP_INSTALL_PATH//\//\\\/}\/bin/g" /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/\@sbindir\@/${PHP_INSTALL_PATH//\//\\\/}\/sbin/g" /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/\@sysconfdir\@/${PHP_INSTALL_PATH//\//\\\/}\/etc/g" /etc/init.d/$PHP_INIT_SCRIPT)
	$(sed -i -e "s/\@localstatedir\@/${PHP_INSTALL_PATH//\//\\\/}\/var/g" /etc/init.d/$PHP_INIT_SCRIPT)

	$(update-rc.d $PHP_INIT_SCRIPT defaults)
fi

if [ ! -f "$PHP_INSTALL_PATH/etc/php-fpm.conf" ]
then
	echo " - Creating PHP-FPM Global Config File"
	echo "[global]

include=$PHP_INSTALL_PATH/etc/pool.d/*.conf
" > $PHP_INSTALL_PATH/etc/php-fpm.conf
fi

if [ ! -d "$PHP_INSTALL_PATH/etc/pool.d" ]
then
	$(mkdir $PHP_INSTALL_PATH/etc/pool.d)
fi

if [ ! -f "$PHP_INSTALL_PATH/etc/pool.d/_default.conf" ]
then
	echo "[_default]

user = www-data
group = www-data
listen = /run/php${PHP_VERSION}-fpm_default.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
" > $PHP_INSTALL_PATH/etc/pool.d/_default.conf
fi

echo "
####################################
Installing Extensions
####################################"

# Install Extensions
IFS=""
for PHP_EXT_ARRAY in ${PHP_EXTENSIONS[@]}; do
	IFS=', ' read -r -a PHP_EXT <<< "${PHP_EXT_ARRAY}"

	EXT_NAME="${PHP_EXT[0]}"
	EXT_SHORT_NAME="${PHP_EXT[1]}"
	EXT_URL="${PHP_EXT[2]}"
	EXT_FILE="${PHP_EXT[3]}"
	EXT_DIR="${PHP_EXT[4]}"
	EXT_MODULE="${PHP_EXT[5]}"

	if [ ! -d "/opt/source/$EXT_DIR" ]
	then

		error "ERROR: Extracting $EXT_NAME File!"

	else
		echo ""
		echo "Installing Extension: ${EXT_NAME} - - - "
		cd /opt/source/$EXT_DIR
		echo " - ${EXT_NAME}: Running Make Clean..."
		if [ $DEBUG == 0 ]
		then
			MAKE_CLEAN=$(make clean -s &>/dev/null)
		elif [ $DEBUG == 1 ]
		then
			MAKE_CLEAN=$(make clean 1>/dev/null)
		elif [ $DEBUG == 2 ]
		then
			MAKE_CLEAN=$(make clean)
		fi
		echo " - ${EXT_NAME}: Running PHPIZE..."
		PHP_IZE=$($PHP_INSTALL_PATH/bin/phpize)
		if [ $? -ne 0 ]
		then
			echo "${PHP_IZE}"
			error "ERROR: Running PHPIZE for $EXT_NAME ($PHP_INSTALL_PATH/bin/phpize)"
		fi
		echo " - ${EXT_NAME}: Running Configuring..."
		EXT_CONFIGURE=$(./configure $Q_DBG --prefix=$PHP_INSTALL_PATH/$EXT_SHORT_NAME --with-php-config=$PHP_INSTALL_PATH/bin/php-config)
		if [ $? -ne 0 ]
		then
			echo "${EXT_CONFIGURE}"
			error "ERROR: Configuring $EXT_NAME"
		fi
		echo " - ${EXT_NAME}: Configure Complete!"
		echo " - ${EXT_NAME}: Running Make..."
		if [ $DEBUG == 0 ]
		then
			EXT_MAKE=$(make -s &>/dev/null)
		elif [ $DEBUG == 1 ]
		then
			EXT_MAKE=$(make 1>/dev/null)
		elif [ $DEBUG == 2 ]
		then
			EXT_MAKE=$(make)
		fi

		if [ $? -ne 0 ]
		then
			echo "${EXT_MAKE}"
			error "ERROR: Make on $EXT_NAME"
		fi
		echo " - ${EXT_NAME}: Make Complete!"
		echo " - ${EXT_NAME}: Running Make Install..."

		if [ $DEBUG == 0 ]
		then
			EXT_MAKEINSTALL=$(make install -s &>/dev/null)
		elif [ $DEBUG == 1 ]
		then
			EXT_MAKEINSTALL=$(make install 1>/dev/null)
		elif [ $DEBUG == 2 ]
		then
			EXT_MAKEINSTALL=$(make install)
		fi

		if [ $? -ne 0 ]
		then
			echo "${EXT_MAKEINSTALL}"
			error "ERROR: Make Intall on $EXT_NAME"
		fi

		echo " - ${EXT_NAME}: Make Install Complete!"

		EXT_LOCATION=$(find $PHP_INSTALL_PATH/lib/php/*/*/$EXT_MODULE)

		if [ "$EXT_LOCATION" != "" ] && [ -f $EXT_LOCATION ] && [ -f "$PHP_INSTALL_PATH/lib/php.ini" ]
		then
			echo " - Adding $EXT_NAME to PHP $PHP_VERSION"

			if [ "$EXT_SHORT_NAME" == "zendopcache" ]
			then
				EXT_CARRIER="zend_extension"
			else
				EXT_CARRIER="extension"
			fi

			echo "$EXT_CARRIER=$EXT_LOCATION" >> $PHP_INSTALL_PATH/lib/php.ini
		else
			error "Error: Could not add $EXT_NAME to PHP $PHP_VERSION"
		fi

	fi
done

kill "$!" # kill the spinner
wait $! 2>/dev/null

echo ""
if [ -d "/opt/source/php-$PHP_VERSION" ]
then
	echo "Removing Build Folder"
	$(rm -rf /opt/source/php-$PHP_VERSION)
fi

echo ""
echo "
#############################################################

Success!
PHP Version $PHP_VERSION was installed Successfully!

#############################################################
"

$PHP_INSTALL_PATH/bin/php -v

echo "
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

PHP Location:         $PHP_INSTALL_PATH
PHP Binary:           $PHP_INSTALL_PATH/bin/php
PHP Version Test:     $PHP_INSTALL_PATH/bin/php -v
PHP Info Test:        $PHP_INSTALL_PATH/bin/php -i
PHP FPM Pool Dir:     $PHP_INSTALL_PATH/etc/pool.d/

Start PHP:            sudo service $PHP_INIT_SCRIPT start

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
"
