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
adduser $installUser
usermod -a -G sudo $installUser
usermod -a -G www-data $installUser

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
echo "----- Setup for Unattended Updates, ReStarts, and AutoClean"
echo "-----------------------------------------------------------------"

apt-get -y install unattended-upgrades

cat <<EOF> "/etc/apt/apt.conf.d/10periodic"
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat << EOF > "/etc/apt/apt.conf.d/50unattended-upgrades"
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

