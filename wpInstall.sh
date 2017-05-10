#!/bin/bash
# WordPress Installer
# by itcarsales
# DigitalOcean Droplet WordPress Installer

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi

echo "------------------------------------------------------------"
echo "               Welcome to the WordPress Dropper"
echo "       Create and Configure New WordPress Virtual Servers"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

installNow=false
while [ $installNow == false ]
do
    echo && read -p "Please enter your new domain name (example.com):" newDomain && echo
    mysqlUser=$(echo $newDomain | sed 's/\..*$//')
    mysqlDB=$mysqlUser"db"
    echo && read -p "Please enter a password for your new WordPress account:" newDomainPass && echo
    echo && read -p "Please enter a password for the new MySQL user:" mysqlUserPass && echo
    echo && read -p "Please enter your MySQL root password:" mysqlRootPass && echo

    echo "-- New Domain Info"
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
mkdir -p $newDomain/logs $newDomain/public
chmod -R 755 $newDomain

sudo cat << EOF >> "$HOME/$newDomain.conf"
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
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php7.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }
}
EOF
sudo cp --no-preserve=mode,ownership ~/$newDomain.conf /etc/nginx/sites-available/$newDomain
sudo rm ~/$newDomain.conf

sudo ln -s /etc/nginx/sites-available/$newDomain /etc/nginx/sites-enabled/$newDomain

sudo systemctl restart nginx


# Setup Wordpress Database and Users
cat << EOF >> "$HOME/wp.sql"
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
wp core install --url=http://$newDomain --title='New WordPress Site' --admin_user=$USER --admin_email=admin@$newDomain --admin_password=$newDomainPass

echo "------------------------------------------------------------"
echo "----- WordPress install Complete"
echo "available at: http://$newDomain/wp-admin"
echo "username: $USER"
echo "password: $newDomainPass"
echo "------------------------------------------------------------"

