#!/bin/bash
# Droplet Lockdown - Ubuntu 16.04LTS x64
# by itcarsales
# DigitalOcean Droplet Secure Setup

if [ "$(id -u)" != "0" ]; then
	echo "ERROR: INVALID PERMISSIONS (Sorry, please run this script as root on a fresh droplet)"
	exit 1
fi

echo "------------------------------------------------------------"
echo "      Welcome to Droplet Lockdown - Ubuntu 16.04LTS x64"
echo "         Initial Setup and Config for a Fresh Droplet"
echo "-------------------     by itcarsales     ------------------"
echo "------------------------------------------------------------"

# Set Timezone and Local options
dpkg-reconfigure tzdata

# Prompt for username and setup primary user
echo && read -p "Please enter your primary username:" installUser && echo
adduser -d /var/www -G www-data $installUser
usermod -a -G sudo $installUser

# Update Server and install ufw + fail2ban
apt-get -y update
apt-get -y install ufw fail2ban
apt-get -y upgrade
apt-get -y autoremove

echo "-----------------------------------------------------------------"
echo "----- Firewall Setup - UFW to allow SSH, HTTP, HTTPS"
echo "-----------------------------------------------------------------"
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
ufw show added
ufw status verbose

echo "-----------------------------------------------------------------"
echo "----- fail2ban Setup - 10min IP block after 5 failed ssh logon atempts"
echo "-----------------------------------------------------------------"
# Configure fail2ban and set to auto-start - Blocks IP for 10min after 5 failed login attempts
update-rc.d fail2ban enable
service fail2ban start

echo "-----------------------------------------------------------------"
echo "----- Modify /etc/ssh/sshd_config to remove SHH root access"
echo "-----------------------------------------------------------------"
sed -i '/^PermitRootLogin[ \t]\+\w\+$/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config

publicIP="`wget -qO- http://ipecho.net/plain`"
echo "-----------------------------------------------------------------"
echo "----- Rebooting Now - Please Reconnect with Primary User Account"
echo "----- > ssh $installUser@$publicIP"
echo "-----------------------------------------------------------s------"

# Reboot to force new user access and initialize
reboot now

