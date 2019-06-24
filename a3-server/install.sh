#!/bin/bash
steam_home="/home/steam/"
a3_dir="$steam_home"arma3server
yum install epel-release -y
yum install -y glibc libstdc++ glibc.i686 libstdc++.i686 jq unzip dos2unix
useradd -m steam
cp server.sh hc.sh update-mods.sh "$steam_home"
if [ ! -f "$steam_home"config.cfg ]; then
 cp config.cfg "$steam_home"config.cfg
fi
cd "$steam_home" || exit
sudo -u steam bash -c 'curl -sL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -'
sudo -u steam bash -c './steamcmd.sh +login anonymous +quit'
if [ ! -d  $a3_dir ]; then
  if ! mkdir -p $a3_dir; then
    printf "Could not create %s \n" $a3_dir
    exit 1
  fi
fi
chown -R steam:steam "$steam_home"
cat <<EOF > /etc/systemd/system/arma3-server.service
[Unit]
Description=Arma 3 Server
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=${steam_home}server.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-server.service
cat <<EOF > /etc/systemd/system/arma3-hc.service
[Unit]
Description=Arma 3 Headless Client
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=${steam_home}hc.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-hc.service
systemctl daemon-reload

printf "\n"
printf "Please enter steam user credentials for the server\n"
printf "This user should be a blank user, with no games, vallets or anything!\n"
printf "Disable any 2 factor auth for this user\n"
printf "\n"
printf "Arma 3 dedicated server is a free tool, so DO NOT USER YOUR PERSONAL STEAM ACCCOUNT HERE!\n"
printf "\n"
read -rp "username:" STEAMUSER
read -rp "password:" STEAMPASS
if [[ -n $STEAMUSER ]]; then
  sed -i "/STEAMUSER=/c\STEAMUSER=\"${STEAMUSER}\"" "$steam_home"config.cfg
fi
if [[ -n $STEAMPASS ]]; then
  sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAMPASS}\"" "$steam_home"config.cfg
fi

is_set=false
while [[ $is_set = "false" ]]; do
    printf "\n"
    read -rp "Do you want to use the steam workshop to download mods for Arma 3 Server? (y|n)" yn
    if [[ $yn = "y" || $yn = "n" ]]; then
      is_set=true
    fi
done

if [[ $yn = "y" ]]; then
  printf "\n"
  printf "\n"
  printf "Steam workshop downloads for Arma 3 need an account that owns the Arma 3 Game\n"
  printf "\n"
  printf "Please set the steam users steam guard to mail token, so we can now authentificate on this server\n"
  printf "\n"
  printf "Please enter the steam username, which owns Arma3\n"
  read -rp "username: " STEAMWSUSER
  sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAMWSUSER}\"" "$steam_home"config.cfg
  read -rsp "password: " STEAMWSPASS
  sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAMWSPASS}\"" "$steam_home"config.cfg
  printf "\n"
  sudo -u steam bash -i -c "./steamcmd.sh +login ${STEAMWSUSER} ${STEAMWSPASS} +quit"
  printf "\n"
  printf "Don't forget to configure your mod IDs as a list (WS_IDS) in %sconfig.cfg\n" "$steam_home"
fi

sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAMWSPASS}\"" "$steam_home"config.cfg

printf "\n"
printf "You can now start the server with \'systemctl start arma3-server.service\' \n"
printf "Or you can start the headless client with \'systemctl start arma3-hc.service\' \n"
printf "\n"
printf "The initial start will take some time, as we have to download arma3 server\n"
printf "\n"
printf "Make sure to edit the %sconfig.cfg to match your requirements! \n" "$steam_home"
printf "If you use direct mod download, you will need a .secrets in %s \n" "$steam_home"
printf "\n"
