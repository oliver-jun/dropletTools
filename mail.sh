#!/bin/bash
# Email Setup - Ubuntu 16.04LTS x64
# by itcarsales
# DigitalOcean Email addon - PostFix

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi

echo && read -p "Would you like to setup Server Email? (y/n)" -n 1 -r -s installMail && echo
if [[ $installMail != "Y" && $installMail != "y" ]]; then
	echo "Server Email install cancelled."  
	exit 1
fi

echo "------------------------------------------------------------"
echo "         Welcome to eMail Setup - Ubuntu 16.04LTS x64"
echo "         Select 'Internet Site' during Email Prompts"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

installNow=false
while [ $installNow == false ]
do

    echo && read -p "Please enter your domain name ( ie example.com ):" newDomain && echo
    echo && read -p "Please enter the address where you would like to receive system emails:" newEmail && echo

    echo "------------ Domain Name ---------------"
    echo "Domain name: $newDomain"
    echo "Admin email: $newEmail"
    echo "----------------------------------------"

    echo && read -p "Are these settings correct? (y/n)" -n 1 -r -s installCorrect && echo
    if [[ $installCorrect == "Y" || $installCorrect == "y" ]]; then
        installNow=true
        echo
        read -p "------------   Press enter to continue   ----------------"
    else
        installNow=false
    fi
done

# Update new repos
sudo apt-get -y update

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

# Send Test Messages
echo "This is the root test message." | mail -s "Root Test" root
echo "This is the standard email message" | mail -s "Email Test" $newEmail

rm -f ~/mail.sh
echo "------------------------------------------------------------"
echo "----- Email Setup Complete"
echo "----- Please check for both root and standard email messages"
echo "------------------------------------------------------------"

