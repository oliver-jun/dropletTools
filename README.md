# dropletTools
Custom Droplet Scripts - Includes new droplet lockdown, LEMP setup, and WordPress Virtual Server Installer.

*All tools written for Digital Ocean Ubuntu 16.04LTS x64 droplets ($5/mo 512Mb works well)*

My DigitalOcean referral: https://m.do.co/c/e2d5d9797108

## To secure a fresh droplet:


```ssh root@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/newDroplet.sh ; bash newDroplet.sh```



## To setup LEMP Server:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/LEMP.sh ; bash LEMP.sh```



## To setup WordPress Dropper:

```ssh primaryUser@your.droplet.ip.address```

```wget https://raw.githubusercontent.com/itcarsales/dropletTools/master/wpInstall.sh ; bash wpInstall.sh```

The WordPress Dropper can be reused to install multiple instances of WordPress on a single server.  Some knowledge of DNS and NGINX configuration may be required for advanced installs.  A single-core, 512Mb droplet has proven more than sufficient to run a single instance.

![loader.io Test Report](https://github.com/itcarsales/dropletTools/raw/master/loadTest.jpg)
