#!/bin/bash
# Email Setup - Ubuntu 16.04LTS x64
# by itcarsales
# DigitalOcean Email addon - PostFix

if [ "$(id -u)" == "0" ]; then
    echo "ERROR: INVALID PERMISSIONS (Please do not use the sudo command)"
	exit 1
fi

echo "------------------------------------------------------------"
echo "         Welcome to eMail Setup - Ubuntu 16.04LTS x64"
echo "         Select 'Internet Site' during Email Prompts"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

# Update new repos
sudo apt-get -y update
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
echo && read -p "Please enter the address where you would like to receive system emails:" newEmail && echo
sudo sed -i '$a root:          '$newEmail'' /etc/aliases
sudo newaliases

# Send Test Messages
echo "This is the root test message." | mail -s "Root Test" root
echo "This is the standard email message" | mail -s "Email Test" $newEmail

echo "------------------------------------------------------------"
echo "----- Email Setup Complete"
echo "------------------------------------------------------------"

