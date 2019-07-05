# arma3-server-scripts

[![Build Status](https://travis-ci.org/michaelsstuff/arma3-server-scripts.svg?branch=master)](https://travis-ci.org/michaelsstuff/arma3-server-scripts)

<a href="url"><img src="https://community.bistudio.com/wikidata/images/8/80/Arma_3_logo_black.png" align="left" height="80" width="178" ></a>
<br />  
<br />  
<br />  

## Installation

This is for a centOS 7 Host. If the host is freshly deployed, run the install.sh  

```bash
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh

```

## Headless

Edit the ``/home/steam/config.cfg``

Start with  
``systemctl start arma3-hc.service``

## Server

Edit the ``/home/steam/config.cfg``

Create a ``server.cfg`` -> https://community.bistudio.com/wiki/Arma_3_Dedicated_Server#CONFIG_server.cfg

Start with  
``systemctl start arma3-server.service``

### Running with mods

The script will automatically load all mods located in
/home/steam/arma3server/mods/, if they start with a ``@``

To download all mods (like your users would do with arma3sync),
set the ``MODURL`` to your modsource URL and set ``MODUPDATE=true``

Or use steam workshop id to download the mods. 
This variant will require a steam user that has the Arma 3 base game.
The installer will ask if you want the workshop variant and configure it,
or you can do configure it yourself in the config.cfg

### Logging

Arma 3 under linux does not log into prt files.
The scripts for Headless and server provided here will do that for you.

They will log into /home/steam/arma3server/logs/ and create files ``arma3-date-PID.log``

The PID will act as a unique identifier,
if you run server and headless from the same server and location.

It will also only write one log, per execution.
