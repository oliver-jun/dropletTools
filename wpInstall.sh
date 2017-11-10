#!/bin/bash
# WordPress Installer
# by itcarsales
# DigitalOcean Droplet WordPress Installer

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi
cd ~/

echo "------------------------------------------------------------"
echo "               Welcome to the WordPress Dropper"
echo "       Create and Configure New WordPress Virtual Servers"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

installNow=false
while [ $installNow == false ]
do
    echo && read -p "Please enter your new domain name (example.com):" newDomain && echo
    mysqlUser=$(echo $newDomain | sed 's/\..*$//' | sed 's/\-//g')
    mysqlDB=$mysqlUser"db"
    echo && read -p "Please enter a password for your new WordPress account:" newDomainPass && echo
    echo && read -p "Please enter a password for the new MySQL user:" mysqlUserPass && echo
    echo && read -p "Please enter your MySQL root password:" mysqlRootPass && echo

    echo "---------- New Domain Info -------------"
    echo "Domain Name: $newDomain" 
    echo "MySQL User: $mysqlUser@localhost" 
    echo "MySQL User password: $mysqlUserPass"
    echo "MySQL Database: $mysqlDB" 
    echo "MySQL root password: $mysqlRootPass"
    echo "----------------------------------------"

    echo && read -p "Are these settings correct? (y/n)" -n 1 -r -s installCorrect && echo
    if [[ $installCorrect == "Y" || $installCorrect == "y" ]]; then
        installNow=true
        echo "These settings will be needed during WordPress Initial Setup"
    else
        installNow=false
    fi
done

cd ~/
mkdir -p $newDomain/logs $newDomain/backups $newDomain/config $newDomain/scripts $newDomain/public
chmod -R 755 $newDomain

# Setup Basic Block to establish LetsEncrypt, then replace with actual block
sudo cat << EOF > "$HOME/$newDomain.conf"
server {
    listen 80;
    listen [::]:80;
    server_name $newDomain www.$newDomain;

    access_log $HOME/$newDomain/logs/access.log;
    error_log $HOME/$newDomain/logs/error.log;

    root $HOME/$newDomain/public/;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args; 
    }

    location ~ \.php$ {
        try_files \$uri =404;

    }
}
EOF
sudo cp --no-preserve=mode,ownership ~/$newDomain.conf /etc/nginx/sites-available/$newDomain
sudo rm ~/$newDomain.conf
sudo ln -s /etc/nginx/sites-available/$newDomain /etc/nginx/sites-enabled/$newDomain
sudo systemctl restart nginx

# Setup SSL with LetsEncrypt/CertBot - Request Certificate
sudo letsencrypt certonly --webroot -w ~/$newDomain/public -d $newDomain -d www.$newDomain
sudo systemctl restart nginx
 
# Setup Actual Server Block with SSL
sudo cat << EOF > "$HOME/$newDomain.conf"
fastcgi_cache_path $HOME/$newDomain/cache levels=1:2 keys_zone=$newDomain:100m inactive=60m;

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate /etc/letsencrypt/live/$newDomain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$newDomain/privkey.pem;

    server_name $newDomain www.$newDomain;

    access_log $HOME/$newDomain/logs/access.log;
    error_log $HOME/$newDomain/logs/error.log;

    root $HOME/$newDomain/public/;
    index index.php;

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
    server_name $newDomain www.$newDomain;

    return 301 https://\$server_name\$request_uri;
}
EOF
sudo cp --no-preserve=mode,ownership ~/$newDomain.conf /etc/nginx/sites-available/$newDomain
sudo rm ~/$newDomain.conf
sudo ln -s /etc/nginx/sites-available/$newDomain /etc/nginx/sites-enabled/$newDomain
sudo systemctl restart nginx

# Setup Wordpress Database and Users
cat << EOF > "$HOME/wp.sql"
CREATE DATABASE $mysqlDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;
CREATE USER $mysqlUser@localhost IDENTIFIED BY '$mysqlUserPass';
GRANT ALL PRIVILEGES ON $mysqlDB.* TO '$mysqlUser'@'localhost';
FLUSH PRIVILEGES;
EOF

mysql -u "root" "-p$mysqlRootPass" < ~/wp.sql
rm ~/wp.sql

cd ~/$newDomain/public
wp core download
wp core config --dbname=$mysqlDB --dbuser=$mysqlUser --dbpass=$mysqlUserPass
wp core install --url=https://$newDomain --title='New WordPress Site' --admin_user=$USER --admin_email=admin@$newDomain --admin_password=$newDomainPass

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

# LetsEncrypt renewal - 12am daily - skips certs not due in next 30days 
echo "0 0 * * * /root/SSLrenew.sh >> /var/log/SSLrenew.log" | sudo crontab -

# Create renewal script - logs to /var/log/SSLrenew.log
cat << EOF > "$HOME/SSLrenew.sh"
#!/bin/bash
date +%d-%m-%y/%H:%M:%S
letsencrypt renew
/usr/sbin/service nginx reload
echo "----------------------------------------"
EOF

sudo mv $HOME/SSLrenew.sh /root/SSLrenew.sh
sudo chown -R root /root/SSLrenew.sh
sudo chmod +x /root/SSLrenew.sh

# Create backup script
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

# Cleanup and move original files to .backups
mv ~/*.old ~/.backups

echo "------------------------------------------------------------"
echo "----- WordPress install Complete"
echo "available at: https://$newDomain/wp-admin"
echo "username: $USER"
echo "password: $newDomainPass"
echo "------------------------------------------------------------"

