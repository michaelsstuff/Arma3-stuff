# arma3-for-hcloud

<a href="url">
<img src="https://community.bistudio.com/wikidata/images/8/80/Arma_3_logo_black.png" align="left" height="80" ></a>
<br />  
<br />  
<br />  
<a href="url"><img src="https://docs.hetzner.cloud/images/logo.svg" align="left" height="80" ></a>
<br />  
<br />  
<br />  

## Usage

```sh
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/arma3-for-hcloud/
```

Create a sshkey pair (id_ecdsa & id_ecdsa.pub)

`ssh-keygen -t ecdsa-sha2-nistp384 -N "" -f ./id_ecdsa`

Create a .env file, which contains your deplyoment informations:

```ini
HCLOUD_TOKEN=""
SERVERTYPE=cx41
HCTYPE=cx21
SSHNAME="a3stuff"
STEAM_USER_SRV=""
STEAM_PASW_SRV=""
STEAM_WS_USER_SRV=""
STEAM_WS_PASW_SRV=""
CRYPTKEY=""
```

### HCLOUD_TOKEN

Log into  console.hetzner.cloud, go to your Project -> Access -> API TOKENS

``HCLOUD_TOKEN=XXXXXXXXXXXXXXXXXXXXXXX``

### CRYPTKEY

Create a cryptokey to store the passwords:

`CRYPTKEY=$(< /dev/urandom hexdump -n 16 -e '4/4 "%08X" 1 "\n"')`

And save it to the  .env file:

`CRYPTKEY=xyb9OH6xshNRx55mCmzhp2BMqDMVNMfi`

### STEAM_USER_SRV

Enter a steam username. This account should not have any Licences, Games or Vallets configured. 
This account will be used to run the server. Arma 3 Server is free tool, and does not require any purchase.
The account should not use any 2 Factor auth. 

`STEAM_USER_SRV="myAwsomeunsafeAccount"`

### STEAM_PASW_SRV

We need an encrypted password for this field. You can genereate it like this:

`echo "MySteamPassord" | openssl enc -a -e -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}"`

### STEAM_WS_USER_SRV

This account is needed to download the Arma 3 Steam Workshop items. Unfortunatley here we need an account that owns Arma3.
We will only use this account to download the workshop items, not to run the server.

### STEAM_WS_PASW_SRV

We need an encrypted password for this field. You can genereate it like this:

`echo "MySteamPassord" | openssl enc -a -e -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}"`

## Build and start like this

```sh
docker build -t arma3-hetzner/deploy .
docker run -it --env-file .env arma3-hetzner/deploy:latest deploy
```

## To remove the servers, but not the volumes and IP

```sh
docker run -it --env-file .env arma3-hetzner/deploy:latest remove
```
