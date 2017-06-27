#!/bin/bash
# WordServer Setup - Ubuntu 16.04LTS x64
# by itcarsales
# LEMP Stack - NGINX, MariaDB, PHP7.1, and WP-CLI

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi

echo "------------------------------------------------------------"
echo "    Welcome to WordServer Setup - Ubuntu 16.04LTS x64"
echo "          NGINX - MariaDB - PHP 7.1 - WordPress CLI"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

echo && read -p "Would you like to install WordServer? (y/n)" -n 1 -r -s installWord && echo
if [[ $installWord != "Y" && $installWord != "y" ]]; then
	echo "WordServer install cancelled."  
	exit 1
fi

installNow=false
while [ $installNow == false ]
do
    echo && read -p "Please enter your new domain name (example.com):" newDomain && echo
    mysqlUser=$(echo $newDomain | sed 's/\..*$//' | sed 's/\-//g')
    mysqlDB=$mysqlUser"db"
    echo && read -p "Please enter a password for your new WordPress account:" newDomainPass && echo
    echo && read -p "Please enter a password for the new MySQL user:" mysqlUserPass && echo
    echo && read -p "Please enter your MySQL root password:" mysqlRootPass && echo
    echo && read -p "Please enter the address where you would like to receive system emails:" newEmail && echo

    echo "---------- New Domain Info -------------"
    echo "Domain Name: $newDomain" 
    echo "MySQL User: $mysqlUser@localhost" 
    echo "MySQL User password: $mysqlUserPass"
    echo "MySQL Database: $mysqlDB" 
    echo "MySQL root password: $mysqlRootPass"
    echo "System Email: $newEmail"
    echo "----------------------------------------"

    echo && read -p "Are these settings correct? (y/n)" -n 1 -r -s installCorrect && echo
    if [[ $installCorrect == "Y" || $installCorrect == "y" ]]; then
        installNow=true
        echo
        echo "---------------- PLEASE SAVE THESE SETTINGS ----------------"
        echo "---  They will be needed during WordPress Initial Setup  ---"
        read -p "---------------   Press enter to continue   ----------------"
    else
        installNow=false
    fi
done

# Set Timezone and Local options
sudo dpkg-reconfigure tzdata

# Create .backups
mkdir ~/.backups

# Add user to www-data and sudo groups
sudo usermod -a -G sudo $USER
sudo usermod -a -G www-data $USER

# Install Repo Management
sudo apt-get -y install software-properties-common

# MariaDB Repo
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.1/ubuntu xenial main'

# PHP 7.1 Repo
sudo add-apt-repository ppa:ondrej/php -y

# Mainline NGINX Repo
sudo add-apt-repository ppa:nginx/development -y

# Update Server and install ufw + fail2ban
sudo apt-get -y update
sudo apt-get -y install ufw fail2ban
sudo apt-get -y upgrade
sudo apt-get -y autoremove

echo "-----------------------------------------------------------------"
echo "----- Firewall Setup - UFW to allow SSH, HTTP, HTTPS"
echo "-----------------------------------------------------------------"
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
yes | sudo ufw enable
sudo ufw show added
sudo ufw status verbose

echo "-----------------------------------------------------------------"
echo "----- fail2ban Setup - 10min IP block after 5 failed ssh logon atempts"
echo "-----------------------------------------------------------------"
# Configure fail2ban and set to auto-start - Blocks IP for 10min after 5 failed login attempts
sudo update-rc.d fail2ban enable
sudo service fail2ban start

echo "-----------------------------------------------------------------"
echo "----- Setup for Unattended Updates, ReStarts, and AutoClean"
echo "-----------------------------------------------------------------"

sudo apt-get -y install unattended-upgrades

sudo cat <<EOF> "$HOME/10periodic"
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
sudo mv ~/10periodic /etc/apt/apt.conf.d/10periodic

sudo cat << EOF > "$HOME/50unattended-upgrades"
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}";
        "\${distro_id}:\${distro_codename}-security";
//        "\${distro_id}:\${distro_codename}-updates";
//        "\${distro_id}:\${distro_codename}-proposed";
//        "\${distro_id}:\${distro_codename}-backports";
};

// List of packages to not update (regexp are supported)
Unattended-Upgrade::Package-Blacklist {
//      "vim";
//      "libc6";
//      "libc6-dev";
//      "libc6-i686";
};

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "06:00";
EOF
sudo mv ~/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades

echo "-----------------------------------------------------------------"
echo "----- Modify /etc/ssh/sshd_config to remove SHH root access"
echo "-----------------------------------------------------------------"
sudo sed -i '/PermitRootLogin /c\PermitRootLogin no' /etc/ssh/sshd_config

#Purge mySQL
sudo apt-get -y purge mysql*
sudo systemctl stop mysqld
sudo rm -rf /etc/mysql /var/lib/mysql

# Setup mariaDB
export DEBIAN_FRONTEND="noninteractive"
sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password password $mysqlRootPass"
sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $mysqlRootPass"
sudo apt-get install -y mariadb-server

sudo systemctl stop mysqld
sudo mysql_install_db
sudo systemctl start mysql

# Because SQL will not accept piped shell commands, I apply Bash-Jutsu to secure it manually.
cat << EOF > "$HOME/secure.sql"
UPDATE mysql.user SET Password=PASSWORD('$mysqlRootPass') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
mysql -u "root" "-p$mysqlRootPass" < ~/secure.sql
rm ~/secure.sql

# Install NGINX
sudo apt-get -y install nginx

# Install PHP 7.1
sudo apt-get -y install php7.1-fpm php7.1-common php7.1-mysqlnd php7.1-xmlrpc php7.1-curl php7.1-gd php7.1-imagick php7.1-cli php-pear php7.1-dev php7.1-imap php7.1-mcrypt
sudo systemctl restart php7.1-fpm

# Setup NGINX Config 
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo cp --no-preserve=mode,ownership /etc/nginx/nginx.conf ~/.backups/nginx.conf.old
sudo rm /etc/nginx/nginx.conf

sudo cat << EOF > "$HOME/nginx.conf"
user $USER;
worker_processes 1;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 1024;
	multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 15;
	types_hash_max_size 2048;
	server_tokens off;
	client_max_body_size 64m;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;
	
	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	##
	# Security
	##

	add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;
    add_header X-Xss-Protection "1; mode=block" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

	##
	# Gzip Settings
	##

	gzip on;
	gzip_disable "msie6";

	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 2;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Cache Settings
	##

	fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
	add_header Fastcgi-Cache \$upstream_cache_status;

	##
	# SSL
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;
	ssl_session_timeout 10m;
	add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;

	##
	# Catch-all Virtual Host
	##

	server {
		listen 80 default_server;
		listen [::]:80 default_server;
		server_name _;
		return 444;
	}
}
EOF
sudo cp --no-preserve=mode,ownership ~/nginx.conf /etc/nginx/nginx.conf
sudo rm ~/nginx.conf

# Run PHP as Primary User
sudo cp --no-preserve=mode,ownership /etc/php/7.1/fpm/pool.d/www.conf ~/.backups/www.conf.old
sudo sed -i '/listen.owner = www-data/c\listen.owner = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/listen.group = www-data/c\listen.group = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/user = www-data/c\user = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/group = www-data/c\group = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf

# Set PHP values to match NGINX
sudo cp --no-preserve=mode,ownership /etc/php/7.1/fpm/php.ini ~/.backups/php.ini.old
sudo sed -i '/post_max_size =/c\post_max_size = 64M' /etc/php/7.1/fpm/php.ini
sudo sed -i '/upload_max_filesize =/c\upload_max_filesize = 64M' /etc/php/7.1/fpm/php.ini

# Enable Fast CGI
sudo sed -i '$a fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;' /etc/nginx/fastcgi_params

# Install and Configure Redis Caching
sudo apt-get -y install redis-server php-redis
sudo sed -i '/# maxmemory <bytes>/c\maxmemory 64mb' /etc/redis/redis.conf

#ReStarts
sudo systemctl restart nginx
sudo service redis-server restart
sudo service php7.1-fpm restart

# Setup WordPress CLI and set to executable
cd ~/
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp


echo "------------------------------------------------------------"
echo "                        WordPress Setup"
echo "------------------------------------------------------------"



# Create Directories and set permissions 
cd ~/
mkdir -p $newDomain/logs $newDomain/backups $newDomain/config $newDomain/scripts $newDomain/public $newDomain/ssl
chmod -R 755 $newDomain

# Create Self-Signed SSL Certs
cd ~/$newDomain/ssl
cat << EOF > "$HOME/$newDomain/ssl/$newDomain.ssl.conf"
[ req ]

default_bits        = 2048
default_keyfile     = server-key.pem
distinguished_name  = subject
req_extensions      = req_ext
x509_extensions     = x509_ext
string_mask         = utf8only

[ subject ]

countryName                 = Country Name (2 letter code)
countryName_default         = US

stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = NE

localityName                = Locality Name (eg, city)
localityName_default        = Omaha

organizationName            = Organization Name (eg, company)
organizationName_default    = Dealer Web Tech, LLC

commonName                  = Common Name (e.g. server FQDN or YOUR name)
commonName_default          = $newDomain

emailAddress                = Email Address
emailAddress_default        = admin@$newDomain

[ x509_ext ]

subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer

basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment
subjectAltName         = @alternate_names
nsComment              = "OpenSSL Generated Certificate"

[ req_ext ]

subjectKeyIdentifier = hash

basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
subjectAltName       = @alternate_names
nsComment            = "OpenSSL Generated Certificate"

[ alternate_names ]

DNS.1       = $newDomain
DNS.2       = www.$newDomain
DNS.3       = dbadmin.$newDomain
EOF

# Issue Keys
echo -en "\n\n\n\n\n\n" | openssl req -config $newDomain.ssl.conf -new -sha256 -newkey rsa:2048 -nodes -keyout $newDomain.key -x509 -days 365 -out $newDomain.crt



# Setup Actual Server Block with SSL
sudo cat << EOF > "$HOME/$newDomain.conf"
fastcgi_cache_path $HOME/$newDomain/cache levels=1:2 keys_zone=$newDomain:100m inactive=60m;

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate $HOME/$newDomain/ssl/$newDomain.crt;
    ssl_certificate_key $HOME/$newDomain/ssl/$newDomain.key;

    server_name $newDomain;

    access_log $HOME/$newDomain/logs/access.log;
    error_log $HOME/$newDomain/logs/error.log;

    root $HOME/$newDomain/public/;

    set \$skip_cache 0;

    # POST requests and urls with a query string should always go to PHP
    if (\$request_method = POST) {
        set \$skip_cache 1;
    }   
    if (\$query_string != "") {
        set \$skip_cache 1;
    }   

    # Don’t cache uris containing the following segments
    if (\$request_uri ~* "/wp-admin/|/backdoor/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
        set \$skip_cache 1;
    }   

    # Don’t use the cache for logged in users or recent commenters
    if (\$http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
        set \$skip_cache 1;
    }

	# Don't cache shopping basket, checkout or account pages
	if (\$request_uri ~* "/cart/*\$|/checkout/*\$|/my-account/*\$") {
        	set \$skip_cache 1;
	}

    location / {
        index index.php;
        try_files \$uri \$uri/ /index.php?\$args; 
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php7.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_cache_bypass \$skip_cache;
        fastcgi_no_cache \$skip_cache;
        fastcgi_cache $newDomain;
        fastcgi_cache_valid 60m;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires 2d;
        add_header Cache-Control "public, no-transform";
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name $newDomain;

    return 301 https://\$server_name\$request_uri;
}
EOF
sudo cp --no-preserve=mode,ownership ~/$newDomain.conf /etc/nginx/sites-available/$newDomain
sudo rm ~/$newDomain.conf
sudo ln -s /etc/nginx/sites-available/$newDomain /etc/nginx/sites-enabled/$newDomain
sudo systemctl restart nginx

# Setup Wordpress Database and Users: ( Bash-Jutsu 2 - Revenge of SQL )
cat << EOF > "$HOME/wp.sql"
CREATE DATABASE $mysqlDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
CREATE USER $mysqlUser@localhost IDENTIFIED BY '$mysqlUserPass';
GRANT ALL PRIVILEGES ON $mysqlDB.* TO '$mysqlUser'@'localhost';
FLUSH PRIVILEGES;
EOF
mysql -u "root" "-p$mysqlRootPass" < ~/wp.sql
rm ~/wp.sql

# Install WordPress
cd ~/$newDomain/public
wp core download
wp core config --dbname=$mysqlDB --dbuser=$mysqlUser --dbpass=$mysqlUserPass
wp core install --url=http://$newDomain --title='New WordPress Site' --admin_user=$USER --admin_email=admin@$newDomain --admin_password=$newDomainPass

echo "-----------------------------------------------------------------"
echo "----- Setting up System Daemon Cron with Daily Backup"
echo "-----------------------------------------------------------------"

# Disable WordPress cron and enable System User Cron on 5min job
sudo sed -i '$a /** Custom Settings by itcarsales */' $HOME/$newDomain/public/wp-config.php
sudo sed -i '$a define('\''DISABLE_WP_CRON'\'', true);' $HOME/$newDomain/public/wp-config.php

# WordPress Cron on 5min Loop
(crontab -l ; echo "*/5 * * * * cd $HOME/$newDomain/public; php -q wp-cron.php >/dev/null 2>&1")| crontab -
# WordPress Daily Backups - 5am
(crontab -l ; echo "0 5 * * * cd $HOME/$newDomain/public; $HOME/$newDomain/scripts/backup.sh")| crontab -
# LetsEncrypt renewal - twice daily - skips certs not due in next 30days
(crontab -l ; echo "0 0,12 * * * letsencrypt renew >/dev/null 2>&1")| crontab -

cat << EOF > "$HOME/$newDomain/scripts/backup.sh"
#!/bin/bash
NOW=\$(date +%Y%m%d%H%M%S)
SQL_FILE=\${NOW}_database.sql

# Backup database
/usr/local/bin/wp db export \$SQL_FILE --add-drop-table >/dev/null 2>&1

# Compress the database
gzip \$SQL_FILE

# Backup uploads directory and database, then cleanup
tar -zcf ../backups/\${NOW}_uploadsANDdb.tar.gz wp-content/uploads \$SQL_FILE.gz
rm -f \$SQL_FILE
rm -f \$SQL_FILE.gz

# Remove backup files more than 7 days old
rm -f ../backups/\$(date +%Y%m%d* --date='8 days ago').gz
EOF

cd ~/$newDomain/scripts/
chmod u+x backup.sh

# Install Redis-Object-Cache
cd ~/$newDomain/public/wp-content
wget https://raw.githubusercontent.com/ericmann/Redis-Object-Cache/master/object-cache.php

# Edit wp-config to add cache values for operation and prevent redirects on multisite
sudo sed -i '$a define('\''WP_CACHE'\'', true);' $HOME/$newDomain/public/wp-config.php
sudo sed -i '$a define('\''WP_CACHE_KEY_SALT'\'', '\'''$newDomain''\'');' $HOME/$newDomain/public/wp-config.php

# Edit wp-config to add direct access to store leads
sudo sed -i '$a define('\''FS_METHOD'\'', '\''direct'\'');' $HOME/$newDomain/public/wp-config.php

# Install and Config NGINX-CACHE
cachePath=~/$newDomain/cache
wp plugin install nginx-cache --activate
wp option update nginx_cache_path $cachePath
wp option update nginx_auto_purge 1

echo "------------------------------------------------------------"
echo "             Adminer Setup - Ubuntu 16.04LTS x64"
echo "------------------------------------------------------------"

# Create adminer directory, download file, and set permissions.  Overwrite latest.php to update, index.php is a symLink
mkdir ~/$newDomain/adminer
cd ~/$newDomain/adminer
wget "http://www.adminer.org/latest.php"
wget "https://raw.githubusercontent.com/vrana/adminer/master/designs/price/adminer.css"

# Create main Adminer file to remove root access and include "latest.php" to simplify updates
cat << EOF > "$HOME/$newDomain/adminer/index.php"
<?php
function adminer_object() {
    class AdminerNoRoot extends Adminer {
        function login(\$login, \$password) {
            return (\$login != 'root');
        } 
    } 
    return new AdminerNoRoot;
}
include "latest.php";
EOF

# Set Permissions
chmod -R 755 ~/$newDomain/adminer


# Setup Actual Server Block with SSL
sudo cat << EOF > "$HOME/adminer.conf"
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

        server_name dbadmin.$newDomain;
        root $HOME/$newDomain/adminer;
        
        ssl_certificate $HOME/$newDomain/ssl/$newDomain.crt;
        ssl_certificate_key $HOME/$newDomain/ssl/$newDomain.key;

        # If you want to use a .htpass file, uncomment the three following lines.
        #auth_basic "Admin-Area! Password needed!";
        #auth_basic_user_file /usr/share/webapps/adminer/.htpass;
        #access_log /var/log/nginx/adminer-access.log;

        access_log $HOME/$newDomain/logs/adminer.access.log;
        error_log $HOME/$newDomain/logs/adminer.error.log;

        location / {
            index index.php;        
            try_files \$uri \$uri/ /index.php?\$args;        
        }

        location ~ [^/]\\.php(/|$) {
            fastcgi_split_path_info ^(.+?\\.php)(/.*)$;
            if (!-f \$document_root\$fastcgi_script_name) {
                return 404;
            }
            fastcgi_pass unix:/run/php/php7.1-fpm.sock;
            fastcgi_param HTTP_PROXY "";
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
}

server {
    listen 80;
    listen [::]:80;
    server_name dbadmin.$newDomain;

    return 301 https://\$server_name\$request_uri;
}

EOF
sudo cp --no-preserve=mode,ownership ~/adminer.conf /etc/nginx/sites-available/adminer.conf
sudo rm ~/adminer.conf
sudo ln -s /etc/nginx/sites-available/adminer.conf /etc/nginx/sites-enabled/adminer.conf
sudo systemctl restart nginx

# Install Mail
export DEBIAN_FRONTEND="noninteractive"
sudo debconf-set-selections <<< "postfix postfix/mailname string $newDomain"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt -y install mailutils

# Backup PostFix config
sudo cp --no-preserve=mode,ownership /etc/postfix/main.cf ~/.backups/main.cf.old

# Setup PostFix config
sudo sed -i '/inet_interfaces =/c\inet_interfaces = loopback-only' /etc/postfix/main.cf
sudo sed -i '/mydestination =/c\mydestination = $myhostname, localhost.$mydomain, $mydomain' /etc/postfix/main.cf
sudo sed -i '$a #Custom Encryption Rule - itcarsales' /etc/postfix/main.cf
sudo sed -i '$a smtp_tls_security_level = may' /etc/postfix/main.cf
sudo systemctl restart postfix

# Update System Alert email
sudo sed -i '$a root:          '$newEmail'' /etc/aliases
sudo newaliases

# Install Complete
ipAddress=$(ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n')
echo "-----------------------------------------------------------------"
echo "----- WordServer Setup Complete"
echo "-----------------------------------------------------------------"
echo "verify with: https://$ipAddress"
echo "-----------------------------------------------------------------"
echo "Paste these into your Linux shell now to access your domains:"
echo ""
echo "sudo sed -i '\$a $ipAddress        $newDomain' /etc/hosts"
echo ""
echo "sudo sed -i '\$a $ipAddress        dbadmin.$newDomain' /etc/hosts"
echo ""
echo "-----------------------------------------------------------------"
echo "Domain: https://$newDomain"
echo "Admin: https://$newDomain/wp-admin"
echo "username: $USER"
echo "password: $newDomainPass"
echo "-----------------------------------------------------------------"
echo "Adminer: https://dbadmin.$newDomain"
echo "username: $mysqlUser"
echo "password: $mysqlUserPass"
echo "database: $mysqlDB"
echo "-----------------------------------------------------------------"

# Reboot to initialize
sudo reboot now

