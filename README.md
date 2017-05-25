# dropletTools
Custom Droplet Scripts - Includes new droplet lockdown, LEMP setup, WordPress Virtual Server Installer, and Email setup.

*All tools written for Digital Ocean Ubuntu 16.04LTS x64 droplets ($5/mo 512Mb works well)*

My DigitalOcean referral: https://m.do.co/c/e2d5d9797108

## Step 1) Secure a fresh droplet:

```ssh root@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/newDroplet.sh ; bash newDroplet.sh```

Features:

- Firewall Setup - UFW to allow SSH, HTTP, HTTPS
- fail2ban Setup - 10min IP block after 5 failed ssh logon atempts
- Unattended Updates, ReStarts, and AutoClean
- Disable SHH root access



## Step 2) Setup LEMP Server:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/LEMP.sh ; bash LEMP.sh```

Features:

- NGINX
- MariaDB
- PHP 7.1
- LetsEncrypt for free SSL Certificates
- Fast CGI and Redis Caching
- WP-CLI for WordPress management


## Step 3) Setup WordPress Dropper:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/wpInstall.sh ; bash wpInstall.sh```

The WordPress Dropper can be reused to install multiple instances of WordPress on a single server.  Some knowledge of WP-CLI, DNS, and NGINX configuration may be required for advanced installs.  A single-core, 512Mb droplet has proven more than sufficient to run a single WordPress instance.

![loader.io Test Report](https://github.com/itcarsales/dropletTools/raw/master/loadTest.jpg)


## Step 4) Setup Email:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/mail.sh ; bash mail.sh```


## Step 5) Setup Adminer for GUI database management:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/adminer.sh ; bash adminer.sh```


## Step 6) Verify Sites:

*Using the following as an example: ( domain: example.com ) Be sure to create and point the "A" Records for both example.com and dbadmin.example.com to your droplet IP address.*

Verify WordPress at https://example.com

Verify WordPress Admin at https://example.com/wp-admin

Verify Adminer at https://dbadmin.example.com

## WordServer for Virtual Machines

WordServer is a work-in-progress.  It is meant to be run on a clean install of Ubuntu Server 16.04 x64.  It provides a mirrored environment to dropletTools for local developers without a droplet.

```ssh primaryUser@your.virtualbox.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/wordserver.sh ; bash wordserver.sh```

