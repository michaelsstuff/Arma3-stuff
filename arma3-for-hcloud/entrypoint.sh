#!/bin/bash
# shellcheck disable=SC2087
#source "config.cfg"
if [ -z "$1" ]; then
  printf "Please specify what to do \n"
  printf "\"deploy\" to deploy servers \n"
  printf "\"remove\" to remove servers \n"
  printf "Warning; \"remove\" will not delete your volumes or floating IPs \n"
  exit 1
fi

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

if [ "$1" = "remove" ]; then
  $hcloud server delete arma3server
  if [ "$HC_COUNT" -gt "0" ]; then
    declare -a hc_ip
    for i in $(seq 1 "$HC_COUNT"); do
      $hcloud server delete arma3hc"$i"
    done
  fi
  exit
fi

$hcloud server create --image centos-7 --name arma3server --type ccx21 --ssh-key "$SSHNAME"
ip="$($hcloud server list -o noheader | grep arma3server | awk '{print $4}')"
server_ip=$ip

floating_ip=$(hcloud floating-ip list | grep a3server | awk '{print $4}')
if [[ $floating_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  hcloud floating-ip assign $(hcloud floating-ip list | grep a3server | awk '{print $1}') arma3server
else
  hcloud floating-ip create --type ipv4 --server arma3server --description a3server
  floating_ip=$(hcloud floating-ip list | grep a3server | awk '{print $4}')
fi

sleep 10
while true; do
  test_ssh "$ip" && break
  sleep 1
done

if [ "$MODMETHOD" = "ftp" ]; then
  # add volume creation / grabbing
  volID_arma3server_mods=$(hcloud volume list | grep arma3server-mods | awk '{print $1}')
  re='^[0-9]+$'
  if [[ "$volID_arma3server_mods" =~ $re ]]; then
    printf "Found an existing volume for the server\n"
    hcloud volume attach --automount --server arma3server "$volID_arma3server_mods"
  else
    printf "Creating mod volume for the server\n"
    hcloud volume create --server arma3server --automount --name arma3server-mods --format ext4 --size 50
  fi
fi

cfg="/home/steam/config.cfg"
ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh -s
echo "$CRYPTKEY" > /home/steam/secret.key
sed -i "/STEAMUSER=/c\STEAMUSER=\"${STEAM_USER_SRV}\"" "$cfg"
sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAM_PASW_SRV}\"" "$cfg"
sed -i "/SERVERPASS=/c\SERVERPASS=\"${SERVERPASS}\"" "$cfg"
ip addr add "$floating_ip" dev eth0
EOC

if [ "$MODMETHOD" = "ftp" ]; then
  # create symlink for mounted volume
  ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<'EOC'
vpath=$(grep sdb /proc/mounts | awk '{print $2}')
ln -s "$vpath" /home/steam/arma3server/mods
chown steam:steam /home/steam/arma3server/mods
chown -R steam:steam "$vpath"

EOC

  ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
sed -i "/MODMETHOD=/c\MODMETHOD=ftp" "$cfg"
sed -i "/MODURL=/c\MODURL=${MODURL}" "$cfg"
sed -i "/FTP_USER=/c\FTP_USER=\"${FTP_USER}\"" "$cfg"
sed -i "/FTP_PASS=/c\FTP_PASS=\"${FTP_PASS}\"" "$cfg"
EOC

else
  ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
sed -i "/MODMETHOD=/c\MODMETHOD=false" "$cfg"
EOC
fi

printf "\n"

if [ -n "$HC_COUNT" ]; then
  if [ "$HC_COUNT" -gt "0" ]; then
    declare -a hc_ip
    for i in $(seq 1 "$HC_COUNT"); do
      $hcloud server create --image centos-7 --name arma3hc"$i" --type cx21 --ssh-key "$SSHNAME"
      ip="$($hcloud server list -o noheader | grep arma3hc"$i" | awk '{print $4}')"
      hc_ip+=("$ip")
      steamuser=$(eval echo "$""STEAM_USER_HC""$i")
      steampass=$(eval echo "$""STEAM_PASW_HC""$i")
      sleep 10
      while true; do
        test_ssh "$ip" && break
        sleep 1
      done

      if [ "$MODMETHOD" = "ftp" ]; then
        # add volume creation / grabbing
        volID_arma3hc_mods=$(hcloud volume list | grep arma3hc"$i"-mods | awk '{print $1}')
        re='^[0-9]+$'
        if [[ "$volID_arma3hc_mods" =~ $re ]]; then
          printf "Found an existing volume for the server\n"
          hcloud volume attach --automount --server arma3hc"$i" "$volID_arma3hc_mods"
        else
          printf "Creating mod volume for the server\n"
          hcloud volume create --server arma3hc"$i" --automount --name arma3hc"$i"-mods --format ext4 --size 50
        fi
      fi

      ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh -s
echo "$CRYPTKEY" > /home/steam/secret.key
sed -i "/STEAMUSER=/c\STEAMUSER=\"${steamuser}\"" "$cfg"
sed -i "/STEAMPASS=/c\STEAMPASS=\"${steampass}\"" "$cfg"
sed -i "/SERVERPASS=/c\SERVERPASS=\"${SERVERPASS}\"" "$cfg"
sed -i "/ISHC=/c\ISHC=\"true\"" "$cfg"
sed -i "/SERVER=/c\SERVER=\"${server_ip}\"" "$cfg"

EOC

      if [ "$MODMETHOD" = "ftp" ]; then
        #mount volume
        ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<'EOC'
vpath=$(grep sdb /proc/mounts | awk '{print $2}')
ln -s "$vpath" /home/steam/arma3server/mods
chown -R steam:steam "$vpath"

EOC

        ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
sed -i "/MODMETHOD=/c\MODMETHOD=ftp" "$cfg"
sed -i "/MODURL=/c\MODURL=${MODURL}" "$cfg"
sed -i "/FTP_USER=/c\FTP_USER=\"${FTP_USER}\"" "$cfg"
sed -i "/FTP_PASS=/c\FTP_PASS=\"${FTP_PASS}\"" "$cfg"
EOC

      else
        ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$ip" <<EOC
sed -i "/MODMETHOD=/c\MODMETHOD=false" "$cfg"
EOC

      fi
    done
  fi
fi

# adding localhost for the server itself
hc_ip+=(127.0.0.1)
ssh -T -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i $sshkeyfile root@"$server_ip" <<EOC
sed -i "/HC=/c\HC=(${hc_ip[*]})" "$cfg"

EOC
delete=(127.0.0.1)
# shellcheck disable=SC2128
hc_ip=("${hc_ip[@]/$delete/}")
for i in "${!hc_ip[@]}"; do
  [ -n "${hc_ip[$i]}" ] || unset "hc_ip[$i]"
done

ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i "$sshkeyfile" root@"$server_ip" "systemctl start arma3-server"
for ipadr in "${hc_ip[@]}"; do
  ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -o "UserKnownHostsFile=/dev/null" -i "$sshkeyfile" root@"$ipadr" "systemctl start arma3-server"
done

printf "\n"
printf "Your ArmA 3 Server IP for your players to connecto to is: \n"
printf "\n"
printf "%s \n" "$floating_ip"
printf "\n"
