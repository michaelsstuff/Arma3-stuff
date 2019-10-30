#!/bin/bash
sync_dir=/titanmini/Download/a3ftp
ftp_source="ftp://158.69.123.76"
ftp_target="ftp://u205615.your-storagebox.de/21st/"
ftp_taget_user="u205615"
ftp_target_pass="IFsNX4r4M6IS1BGs"
home="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# logging
TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"+%Y-%m-%d_%H:%M"}
LOGFILE=$HOME/ftp_sync_$(date "$TIMESTAMP_FORMAT").log
# Redirect stdout/stderr to tee to write the log file
exec > >(tee -a "${LOGFILE}") 2>&1

printf "%s Started sync script \n" "$(date +'%Y-%m-%d %H:%M:%S')"

if [ -f "${home}/config.cfg" ]; then
  # shellcheck source=config.cfg
  # shellcheck disable=SC1091
  source "${home}/config.cfg"
else
  printf "Please create %s" "${home}/config.cfg"
fi

# get my decrypt key
if [ -f "${home}"/secret.key ]; then
  CRYPTKEY=$(cat "$home"/secret.key)
else
  printf "Error! Could not find my decryption key for stored passwords.\n"
  exit 1
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

if [[ -z $WS_IDS ]]; then
    printf "Workshop mod IDs not configured, please set WS_IDS in the config.cfg\n"
    exit 1
elif [ -z "${STEAMWSUSER}" ]; then
    printf "STEAMWSUSER is not set, please configure in config.cfg"
    exit 1
elif [ -z "${STEAMWSPASS}" ]; then
    printf "STEAMWSPASS is not set, please configure in config.cfg"
    exit 1
else
    a3_id=107410
    STEAMWSPASS_decrypted=$(decrypt "${STEAMWSPASS}")
    for i in ${WS_IDS[*]}; do
        steamcmd +login "${STEAMWSUSER}" "${STEAMWSPASS_decrypted}" +workshop_download_item "${a3_id}" "$i" +quit
        modname="$(curl -s https://steamcommunity.com/sharedfiles/filedetails/?id="${i}" | grep "<title>" | sed -e 's/<[^>]*>//g' | cut -d ' ' -f 4-)"
        printf "\n"
        modname_clean=$(echo "$modname" | dos2unix)
        #ln -s "${home}/Steam/steamapps/workshop/content/${a3_id}/${i}" "${a3_dir}/mods/@${modname_clean}"
        cd "${a3_dir}/mods/@${modname_clean}" || exit
        for f in $(find ./ -type f | grep "[A-Z]"); do
            mv -i "$f" "$(echo "$f" | tr "[:upper:]" "[:lower:]")"
        done
        cd "$home" || exit
    done
fi

docker run --env-file .env -v /root/test/.steam/:/home/steam/.steam/ -it adfd29270c1a steamcmd +login "${STEAMWSUSER}" "$(echo "${STEAMWSPASS}" | openssl enc -a -d -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}")" +quit

if ! rpm -q lftp; then
    exit 1
fi

if [ ! -d "$sync_dir" ]; then
    if ! mkdir -p "$sync_dir"; then
        printf "Could not create %s \n" "$sync_dir"
        exit 1
    fi
fi

cd "$sync_dir" || exit

#printf "%s Starting download \n" "$(date +'%Y-%m-%d %H:%M:%S')"
lftp -e 'mirror -v /' "$ftp_source"

printf "%s Starting upload \n" "$(date +'%Y-%m-%d %H:%M:%S')"
lftp -e 'mirror -v -R "$sync_dir"' -u "$ftp_taget_user","$ftp_target_pass" "$ftp_target"

printf "%s Stopped sync script \n" "$(date +'%Y-%m-%d %H:%M:%S')"
