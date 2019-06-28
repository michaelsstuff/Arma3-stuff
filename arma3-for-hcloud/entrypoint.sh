#!/bin/bash
#source "config.cfg"
hcloud="/go/bin/hcloud"
sshkeyfile="/root/.ssh/id_ecdsa"
if [ ! -f "$sshkeyfile" ]; then
  printf "Error, no ssh key pair found! Please create a keypair and rebuild the container.\n"
  printf "ssh-keygen -t ecdsa-sha2-nistp384 -N "" -f ./id_ecdsa \n"
  exit 1
fi
sshkeypub="$(cat /root/.ssh/id_ecdsa.pub)"
if [ -z "$SSHNAME" ]; then
  SSHNAME=a3stuff
fi

keyprint="$(ssh-keygen -l -E md5 -f "/root/.ssh/id_ecdsa.pub" | awk '{print $2}' | cut -c 5-)"
mapfile -t hcloudsskkeys <<<"$(hcloud ssh-key list | awk '{print $3}' | tail -n +2)"

if [[ ${hcloudsskkeys[*]} != *"$keyprint"* ]]; then
  $hcloud ssh-key create --name "$SSHNAME" --public-key "$sshkeypub"
fi

if [ -z "$CRYPTKEY" ]; then
  CRYPTKEY=$(hexdump </dev/urandom -n 16 -e '4/4 "%08X" 1 "\n"')
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

test_ssh() {
  ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -i "$sshkeyfile" -q root@"$1" exit
}

$hcloud server create --image centos-7 --name arma3server --type ccx21 --ssh-key "$SSHNAME"
ip="$($hcloud server list -o noheader | grep arma3server | awk '{print $4}')"
server_ip=$ip
sleep 10
while true; do
  test_ssh "$ip" && break
  sleep 1
done

cfg="/home/steam/config.cfg"
ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile /dev/null" -i $sshkeyfile root@"$ip" <<EOC
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh -s
echo "$CRYPTKEY" > /home/steam/secret.key
sed -i "/STEAMUSER=/c\STEAMUSER=\"${STEAM_USER_SRV}\"" "$cfg"
sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAM_PASW_SRV}\"" "$cfg"
sed -i "/MODUPDATE=/c\MODUPDATE=workshop" "$cfg"
sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAM_WS_USER_SRV}\"" "$cfg"
sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAM_WS_PASW_SRV}\"" "$cfg"
sed -i "/WS_IDS=/c\WS_IDS=(${WS_IDS[*]})" "$cfg"
sed -i "/SERVERPASS=/c\SERVERPASS=\"${SERVERPASS}\"" "$cfg"

EOC

printf "\n"

if [ -n "$HC_COUNT" ]; then
  if [ "$HC_COUNT" -gt "0" ]; then
    declare -a hc_ip
    for i in $(seq 1 "$HC_COUNT"); do
      $hcloud server create --image centos-7 --name arma3hc"$i" --type cx21 --ssh-key "$SSHNAME"
      ip="$($hcloud server list -o noheader | grep arma3hc"$i" | awk '{print $4}')"
      hc_ip+=("$ip")
      steamuser=$(eval STEAM_USER_HC"$i")
      steampass=$(eval STEAM_PASW_HC"$i")
      sleep 10
      while true; do
        test_ssh "$ip" && break
        sleep 1
      done
      ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile /dev/null" -i $sshkeyfile root@"$ip" <<EOC
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh -s
echo "$CRYPTKEY" > /home/steam/secret.key
sed -i "/STEAMUSER=/c\STEAMUSER=\"${steamuser}\"" "$cfg"
sed -i "/STEAMPASS=/c\STEAMPASS=\"${steampass}\"" "$cfg"
sed -i "/MODUPDATE=/c\MODUPDATE=workshop" "$cfg"
sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAM_WS_USER_SRV}\"" "$cfg"
sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAM_WS_PASW_SRV}\"" "$cfg"
sed -i "/WS_IDS=/c\WS_IDS=(${WS_IDS[*]})" "$cfg"
sed -i "/SERVERPASS=/c\SERVERPASS=\"${SERVERPASS}\"" "$cfg"
sed -i "/ISHC=/c\ISHC=\"true\"" "$cfg"
sed -i "/SERVER=/c\SERVER=\"${server_ip}\"" "$cfg"

EOC
    done
  fi
fi

STEAM_WS_PASW_SRV_DECRYPTED=$(decrypt "${STEAM_WS_PASW_SRV}")
printf "please log into the arma3server and authentificate once with the steam workshop user \n"
printf "\n"
printf "ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o \"UserKnownHostsFile /dev/null\" -i %s root@%s \"sudo -u steam /home/steam/steamcmd.sh +login %s %s +quit\" \n" "$sshkeyfile" "$server_ip" "${STEAM_WS_USER_SRV}" "${STEAM_WS_PASW_SRV_DECRYPTED}"
printf "\n"
printf "ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o \"UserKnownHostsFile /dev/null\" -i %s root@%s \"systemctl start arma3-server\" \n" "$sshkeyfile" "$server_ip"
printf "\n"
printf "Do the same for the Headless clients: \n"
printf "\n"
for ipadr in "${hc_ip[@]}"; do
  printf "ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o \"UserKnownHostsFile /dev/null\" -i %s root@%s \"sudo -u steam /home/steam/steamcmd.sh +login %s %s +quit\" \n" "$sshkeyfile" "$ipadr" "${STEAM_WS_USER_SRV}" "${STEAM_WS_PASW_SRV_DECRYPTED}"
  printf "ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o \"UserKnownHostsFile /dev/null\" -i %s root@%s \"systemctl start arma3-server\" \n" "$sshkeyfile" "$ipadr"
  printf "\n"
done
printf "\n"
printf "\n"
/bin/bash
