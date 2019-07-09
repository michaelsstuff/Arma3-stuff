#!/usr/bin/env bash
set -e
set -o pipefail
home="/home/steam"
cd "$home" || exit
if [ -f "${home}/config.cfg" ]; then
    # shellcheck source=config.cfg
    # shellcheck disable=SC1091
    source "${home}/config.cfg"
else
    printf "Please create %s, and set at least STEAMUSER and STEAMPASS \n" "${home}/config.cfg"
fi
# get my decrypt key
if [ -z "${CRYPTKEY}" ]; then
    printf "Error! Could not find my decryption key for stored passwords.\n"
    exit 1
fi
if [ -n "$WSCOLLECTIONID" ]; then
 mapfile -t WS_IDS < <(curl -s https://steamcommunity.com/sharedfiles/filedetails/?id="${WSCOLLECTIONID}" | grep "https://steamcommunity.com/sharedfiles/filedetails/?id=" | grep -Eoi '<a [^>]+>' | tail -n +2 | grep -Eo 'href="[^\"]+"' | awk -F'"' '{ print $2 }'|awk -F'=' '{ print $2 }')
fi
# shellcheck disable=2128
if [[ -z $WS_IDS ]]; then
    printf "Workshop mod IDs not configured, please set WS_IDS in the config.cfg\n"
    exit 1
elif [ -z "${STEAMUSER}" ]; then
    printf "STEAMUSER is not set, please configure in config.cfg"
    exit 1
elif [ -z "${STEAMPASS}" ]; then
    printf "STEAMPASS is not set, please configure in config.cfg"
    exit 1
fi
if [ ! -d "$home"/mods ]; then
    if ! mkdir -p "$home"/mods; then
        exit 1
    fi
fi
STEAMPASS_decrypted=$(echo "${STEAMPASS}" | openssl enc -a -d -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}")
for workshop_item in "${WS_IDS[@]}"; do
    modname="$(curl -s https://steamcommunity.com/sharedfiles/filedetails/?id="${workshop_item}" | grep "<title>" | sed -e 's/<[^>]*>//g' | cut -d ' ' -f 4-)"
    modname_clean=$(echo "$modname" | dos2unix)
    counter=1
    printf "Downloading %s \n" "$modname_clean"
    until steamcmd +login "${STEAMUSER}" "${STEAMPASS_decrypted}" +workshop_download_item 107410 "${workshop_item}" validate +quit; do
        printf "Error Downloading %s. Will try again \n" "$modname_clean"
        ((counter++))
        if ((counter > 4)); then
            exit 1
        fi
    done
    if [ ! -L "${home}/mods/@${modname_clean}" ]; then
        ln -s "${home}/.steam/steamapps/workshop/content/107410/${workshop_item}/" "${home}/mods/@${modname_clean}"
    fi
done
