#!/bin/bash
# Adminer Setup - Ubuntu 16.04LTS x64
# by itcarsales
# DigitalOcean Adminer addon - MySQL database tool

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi
echo "------------------------------------------------------------"
echo "         Welcome to Adminer Setup - Ubuntu 16.04LTS x64"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

# Update new repos
sudo apt-get -y update
sudo apt-get -y upgrade

# See if cont. from previous install step
if [ $newDomain ]; then
    echo && read -p "Are you installing to $newDomain? (y/n)" -n 1 -r -s installCorrect && echo
    if [[ $installCorrect == "Y" || $installCorrect == "y" ]]; then
        echo "$newDomain will be used for setup"
    else
        echo && read -p "Please enter your domain name (example.com):" newDomain && echo
    fi
else
    echo && read -p "Please enter your domain name (example.com):" newDomain && echo
fi

# Create adminer directory, download file, and set permissions.  Overwrite latest.php to update, index.php is a symLink
mkdir ~/$newDomain/adminer
cd ~/$newDomain/adminer
wget "http://www.adminer.org/latest.php"
ln -s ~/$newDomain/adminer/latest.php ~/$newDomain/adminer/index.php
chmod -R 755 ~/$newDomain/adminer

# Setup Basic Block to establish LetsEncrypt, then replace with actual block
sudo cat << EOF > "$HOME/adminer.conf"
server {
    listen 80;
    listen [::]:80;

        server_name dbadmin.$newDomain;
        root $HOME/$newDomain/adminer;

        access_log $HOME/$newDomain/logs/adminer.access.log;
        error_log $HOME/$newDomain/logs/adminer.error.log;

        location / {
                index index.php;
                try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php$ {
            try_files \$uri =404;
        }
}
EOF
sudo cp --no-preserve=mode,ownership ~/adminer.conf /etc/nginx/sites-available/adminer.conf
sudo rm ~/adminer.conf
sudo ln -s /etc/nginx/sites-available/adminer.conf /etc/nginx/sites-enabled/adminer.conf
sudo systemctl restart nginx

# Setup SSL with LetsEncrypt/CertBot - Request Certificate
sudo letsencrypt certonly --webroot -w ~/$newDomain/adminer -d dbadmin.$newDomain
sudo systemctl restart nginx

# Setup Actual Server Block with SSL
sudo cat << EOF > "$HOME/adminer.conf"
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

        server_name dbadmin.$newDomain;
        root $HOME/$newDomain/adminer;
        index index.php;

        ssl_certificate /etc/letsencrypt/live/dbadmin.$newDomain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/dbadmin.$newDomain/privkey.pem;

        # If you want to use a .htpass file, uncomment the three following lines.
        #auth_basic "Admin-Area! Password needed!";
        #auth_basic_user_file /usr/share/webapps/adminer/.htpass;
        #access_log /var/log/nginx/adminer-access.log;

        access_log $HOME/$newDomain/logs/adminer.access.log;
        error_log $HOME/$newDomain/logs/adminer.error.log;

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
        fastcgi_param SCRIPT_FILENAME $HOME/$newDomain/adminer\$fastcgi_script_name;
        fastcgi_cache_valid 60m;
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

rm -f ~/adminer.sh
echo "------------------------------------------------------------"
echo "----- Adminer Setup Complete"
echo "----- available at: https://dbadmin.$newDomain"
echo "------------------------------------------------------------"

