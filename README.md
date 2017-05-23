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
- Setup for Unattended Updates, ReStarts, and AutoClean
- Disable SHH root access



## Step 2) Setup LEMP Server:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/LEMP.sh ; bash LEMP.sh```



## Step 3) Setup WordPress Dropper:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/wpInstall.sh ; bash wpInstall.sh```

The WordPress Dropper can be reused to install multiple instances of WordPress on a single server.  Some knowledge of WP-CLI, DNS, and NGINX configuration may be required for advanced installs.  A single-core, 512Mb droplet has proven more than sufficient to run a single WordPress instance.

![loader.io Test Report](https://github.com/itcarsales/dropletTools/raw/master/loadTest.jpg)


## Step 4) Setup Email:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/mail.sh ; bash mail.sh```



## Step 5) Log into your new WordPress site and verify settings and plugins:

*Using the following as an example: ( primaryUser: username | domain: example.com )*

Verify the cache folder for the NGINX plugin:  /home/username/example.com/cache/
