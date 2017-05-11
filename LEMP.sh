#!/bin/bash
# LEMP Setup - Ubuntu 16.04LTS x64
# by itcarsales
# DigitalOcean LEMP Droplet - NGINX, MariaDB, PHP7.1, WP CLI

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi

echo "------------------------------------------------------------"
echo "    Welcome to WordPress LEMP Setup - Ubuntu 16.04LTS x64"
echo "          NGINX - MariaDB - PHP 7.1 - WordPress CLI"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

# Install Repo Management
sudo apt-get install software-properties-common

# MariaDB Repo
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386] http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.1/ubuntu xenial main'

# PHP 7.1 Repo
sudo add-apt-repository ppa:ondrej/php -y

# Mainline NGINX Repo
sudo add-apt-repository ppa:nginx/development -y

# Update new repos
sudo apt-get -y update

# Install LetsEncrypt
sudo apt-get install letsencrypt -y

# Install NGINX
sudo apt-get -y install nginx 

# Install PHP 7.1
sudo apt-get -y install php7.1-fpm php7.1-common php7.1-mysqlnd php7.1-xmlrpc php7.1-curl php7.1-gd php7.1-imagick php7.1-cli php-pear php7.1-dev php7.1-imap php7.1-mcrypt
sudo systemctl restart php7.1-fpm

#Purge mySQL
sudo apt-get -y purge mysql*
sudo systemctl stop mysqld
sudo rm -rf /etc/mysql /var/lib/mysql

# Setup mariaDB
sudo apt-get install mariadb-server -y
sudo systemctl stop mysqld
sudo mysql_install_db
sudo systemctl start mysql
sudo mysql_secure_installation

# Setup NGINX Config 
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo cp --no-preserve=mode,ownership /etc/nginx/nginx.conf ~/nginx.conf.old
sudo rm /etc/nginx/nginx.conf

sudo cat << EOF >> "$HOME/nginx.conf"
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
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;
	
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

	# gzip_vary on;
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
sudo cp --no-preserve=mode,ownership /etc/php/7.1/fpm/pool.d/www.conf ~/www.conf.old
sudo sed -i '/listen.owner = www-data/c\listen.owner = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/listen.group = www-data/c\listen.group = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/user = www-data/c\user = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf
sudo sed -i '/group = www-data/c\group = '$USER'' /etc/php/7.1/fpm/pool.d/www.conf

# Set PHP values to match NGINX
sudo cp --no-preserve=mode,ownership /etc/php/7.1/fpm/php.ini ~/php.ini.old
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
echo "----- LEMP Server Setup Complete"
echo "------------------------------------------------------------"

