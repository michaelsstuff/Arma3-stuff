#!/bin/bash
#
# Please fill out the following variables.
# Or edit the config.cfg
#

home="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
a3_dir="${home}/arma3server" # this could be overwritten by the config.cfg

if [ -f "${home}/config.cfg" ]; then
  # shellcheck source=config.cfg
  # shellcheck disable=SC1091
  source "${home}/config.cfg"
else
  printf "Please create %s, and set at least STEAMUSER and STEAMPASS" "${home}/config.cfg"
fi

# get my decrypt key
if [ -f "${home}"/secret.key ]; then
  CRYPTKEY=$(cat "$home"/secret.key)
else
  printf "Error! Could not find my decryption for stored passwords.\n"
  exit 1
fi

declare -a mods_array
pid=$$

if [ ! -d "$a3_dir"/logs ]; then
  if ! mkdir -p "$a3_dir"/logs; then
    printf "Could not create %s/logs \n" "$a3_dir"
    exit 1
  fi
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

# logging
TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"+%Y-%m-%d"}
LOGFILE=$a3_dir/logs/"arma3"_$(date "$TIMESTAMP_FORMAT")_PID-$pid.log
# Redirect stdout/stderr to tee to write the log file
exec > >(tee -a "${LOGFILE}") 2>&1

# check for required vars
if [ -z "$STEAMUSER" ]; then
  printf "Steam username not given. Please check settings in %s \n" "${home}/config.cfg"
  exit 1
fi

if [ -z "$STEAMPASS" ]; then
  printf "Steam Password not given. Please check settings in %s \n" "${home}/config.cfg"
  exit 1
else
  STEAMPASS_decrypted=$(decrypt "${STEAMPASS}")
fi

SERVERPASS_decrypted=$(decrypt "${SERVERPASS}")

# check if config file exists
if [ ! -f "$a3_dir"/server.cfg ]; then
  printf "Did not find a server.cfg in %s. I will download a default one. \n" "$a3_dir"
  curl -sL https://raw.githubusercontent.com/michaelsstuff/Arma3-stuff/master/a3-server/server.cfg -o "$a3_dir"/server.cfg
fi
sed -i "/\/\/password     =/c\password     = \"${SERVERPASS_decrypted}\";" "$a3_dir"/server.cfg
sed -i "/password     =/c\password     = \"${SERVERPASS_decrypted}\";" "$a3_dir"/server.cfg

# add the Headlessclients to the server config
ip_string="$(echo \{"\"$(echo "${HC[*]}" | sed -e 's/\s\+/","/g')\"};")"
sed -i "/headlessClients\[\]/c\headlessClients\[\] = ${ip_string}" "$a3_dir"/server.cfg

# download arma3 server
cd "$home" || exit
./steamcmd.sh +login "$STEAMUSER" "$STEAMPASS_decrypted" +force_install_dir "$a3_dir" +app_update 233780 validate +quit

# check profile folder
if [ ! -d "${home}/.local/share/Arma 3" ]; then
  if ! mkdir -p "${home}/.local/share/Arma 3"; then
    printf "Could not create %s/.local/share/Arma 3 \n" "$home"
    exit 1
  fi
fi
if [ ! -d "${home}/.local/share/Arma 3 - Other Profiles" ]; then
  if ! mkdir -p "${home}/.local/share/Arma 3 - Other Profiles"; then
    printf "Could not create %s/.local/share/Arma 3 - Other Profiles \n" "$home"
    exit 1
  fi
fi

# download mods if parameter is set
if [ ! -d "$a3_dir"/mods ]; then
  if ! mkdir -p "$a3_dir"/mods; then
    printf "Could not create %s/mods \n" "$a3_dir"
    exit 1
  fi
fi

if [[ $MODMETHOD == "ftp" ]]; then
moddir="${a3_dir}/mods/"
  if [[ -n "${FTP_USER}" ]]; then
    ftp_pw=$(decrypt "${FTP_PASS}")
    lftp -e "mirror --parallel=10 --ignore-time -v / ${moddir}" -u "${FTP_USER}","${ftp_pw}" "${MODURL}"
  else
    lftp -e "mirror --parallel=10 --ignore-time -v / ${moddir}" "${MODURL}"
  fi
elif [[ $MODMETHOD == "direct" ]]; then
  /bin/bash "${home}"/update-mods.sh
fi

# create modlist
cd "$a3_dir" || exit
for d in mods/@*/; do
  mods_array+=("$d")
done
mods=$(
  IFS=$';'
  echo "${mods_array[*]}"
)

# getting tuned basic config, tuned for about 100 Mbit/s synchronous
if [[ $NOBASIC != "true" ]]; then
  if [[ ! -f "${a3_dir}"/basic.md5 ]]; then
    curl -sL https://raw.githubusercontent.com/michaelsstuff/Arma3-stuff/master/a3-server/basic.cfg -o "$a3_dir"/basic.cfg
    md5sum "${a3_dir}"/basic.cfg >"${a3_dir}"/basic.md5
  else
    if ! md5sum -c "${a3_dir}"/basic.md5 --status; then
      curl -sL https://raw.githubusercontent.com/michaelsstuff/Arma3-stuff/master/a3-server/basic.cfg -o "$a3_dir"/basic.cfg
    fi
  fi
fi

# starting the server
cd "$a3_dir" || exit
if [ "$ISHC" == "true" ]; then
  ./arma3server -connect="$SERVER" -port=2302 -password="$SERVERPASS_decrypted" -cfg=basic.cfg -client -loadMissionToMemory -hugepages -bandwidthAlg=2 -mod=\""$mods"\"
else
  ./arma3server -name="$SERVERNAME" -config=server.cfg -cfg=basic.cfg -loadMissionToMemory -hugepages -bandwidthAlg=2 -mod=\""$mods"\"
fi
