#!/bin/bash
steam_home="/home/steam/"
a3_dir="$steam_home"arma3server
yum install epel-release -y
yum install -y glibc libstdc++ glibc.i686 libstdc++.i686 jq unzip dos2unix openssl lftp
id -u steam &>/dev/null || useradd -m steam
cp server.sh update-mods.sh "$steam_home"

if [ "$1" = "-s" ]; then
  silent=true
fi

if [ ! -f ${steam_home}secret.key ]; then
  CRYPTKEY=$(hexdump </dev/urandom -n 16 -e '4/4 "%08X" 1 "\n"')
  echo "$CRYPTKEY" >${steam_home}secret.key
  chmod 600 ${steam_home}secret.key
  chown steam:steam ${steam_home}secret.key
else
  CRYPTKEY=$(cat "$steam_home"secret.key)
fi

encrypt() {
  local encrypt
  encrypt="$(echo "${1}" | openssl enc -a -e -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}" 2>/dev/null)"
  echo "$encrypt"
}

decrypt() {
  local myresult
  myresult="$(echo "${1}" | openssl enc -a -d -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}" 2>/dev/null)"
  echo "$myresult"
}

if [ ! -f "$steam_home"config.cfg ]; then
  cp config.cfg "$steam_home"config.cfg
fi
cd "$steam_home" || exit
sudo -u steam bash -c 'curl -sL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -'
sudo -u steam bash -c './steamcmd.sh +login anonymous +quit'
if [ ! -d $a3_dir ]; then
  if ! mkdir -p $a3_dir; then
    printf "Could not create %s \n" $a3_dir
    exit 1
  fi
fi
chown -R steam:steam "$steam_home"
cat <<EOF >/etc/systemd/system/arma3-server.service
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
systemctl daemon-reload

if [ $silent = "true" ]; then
  exit
fi

# shellcheck source=config.cfg
# shellcheck disable=SC1091
source "$steam_home"config.cfg

printf "\n"
printf "Please enter steam user credentials for the server\n"
printf "This user should be a blank user, with no games, vallets or anything!\n"
printf "Disable any 2 factor auth for this user\n"
printf "\n"
printf "Arma 3 dedicated server is a free tool, so DO NOT USER YOUR PERSONAL STEAM ACCCOUNT HERE!\n"
printf "\n"
read -rp "username (${STEAMUSER}):" STEAMUSER_new
if [[ -n $STEAMUSER_new ]]; then
  STEAMUSER=${STEAMUSER_new}
  sed -i "/STEAMUSER=/c\STEAMUSER=\"${STEAMUSER}\"" "$steam_home"config.cfg
fi

# shellcheck disable=2153
if [[ -n $STEAMPASS ]]; then
  STEAMPASS_decrypted=$(decrypt "${STEAMPASS}")
fi
read -rp "password (${STEAMPASS_decrypted}):" STEAMPASS_new
if [[ -n $STEAMPASS_new ]]; then
  STEAMPASS_new_crypted=$(encrypt "${STEAMPASS_new}")
  sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAMPASS_new_crypted}\"" "$steam_home"config.cfg
fi

is_set=false
while [[ $is_set == "false" ]]; do
  printf "\n"
  read -rp "Do you want to use the steam workshop to download mods for Arma 3 Server? (y|n)" yn
  if [[ $yn == "y" || $yn == "n" ]]; then
    is_set=true
  fi
done

if [[ $yn == "y" ]]; then
  printf "\n"
  printf "\n"
  printf "Steam workshop downloads for Arma 3 need an account that owns the Arma 3 Game\n"
  printf "\n"
  printf "Please set the steam users steam guard to mail token, so we can now authentificate on this server\n"
  printf "\n"
  printf "Please enter the steam username, which owns Arma3\n"

  read -rp "username (${STEAMWSUSER}):" STEAMWSUSER_new
  if [[ -n $STEAMWSUSER_new ]]; then
    STEAMWSUSER=${STEAMWSUSER_new}
    sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAMWSUSER}\"" "$steam_home"config.cfg
  fi

  # shellcheck disable=2153
  if [[ -n $STEAMWSPASS ]]; then
    STEAMWSPASS_decrypted=$(decrypt "${STEAMWSPASS}")
  fi
  read -rp "password (${STEAMWSPASS_decrypted}):" STEAMWSPASS_new
  if [[ -n $STEAMWSPASS_new ]]; then
    STEAMWSPASS_new_crypted=$(encrypt "${STEAMWSPASS_new}")
    sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAMWSPASS_new_crypted}\"" "$steam_home"config.cfg
  fi

  sed -i "/MODUPDATE=/c\MODUPDATE=workshop" "$steam_home"config.cfg
  printf "\n"
  sudo -u steam bash -i -c "./steamcmd.sh +login ${STEAMWSUSER} ${STEAMWSPASS} +quit"
  printf "\n"

  is_ynids_set=false
  while [[ $is_ynids_set == "false" ]]; do
    printf "\n"
    read -rp "Do you want to configure the modlist now? You will need the workshop item IDs for this. (y|n)" ynids
    printf "\n"
    if [[ $ynids == "y" || $ynids == "n" ]]; then
      is_ynids_set=true
    fi
  done
  declare -a ws_ids
  if [[ $ynids == "y" ]]; then
    numbers_finished=false
    while [ "$numbers_finished" == "false" ]; do
      read -rp "Workshop ID or empty if you are finished:" id
      if [[ $id =~ ^[0-9]+$ ]]; then
        ws_ids+=("$id")
      else
        numbers_finished=true
      fi
    done
    sed -i "/WS_IDS=/c\WS_IDS=(${ws_ids[*]})" "$steam_home"config.cfg
  else
    printf "Don't forget to configure your mod IDs as a list (WS_IDS) in %sconfig.cfg\n" "$steam_home"
  fi
fi

printf "\n"
printf "You can now start the server with \'systemctl start arma3-server.service\' \n"
printf "\n"
printf "The initial start will take some time, as we have to download arma3 server\n"
printf "\n"
printf "Make sure to edit the %sconfig.cfg to match your requirements! \n" "$steam_home"
printf "If you use direct mod download, you will need a .secrets in %s \n" "$steam_home"
printf "\n"
