#!/bin/bash

home="/home/steam"
cd "$home" || exit

if ! rpm -q lftp; then
    printf "Please install lftp \n"
    exit 1
fi

if [ -f "${home}/config.cfg" ]; then
    # shellcheck source=config.cfg
    # shellcheck disable=SC1091
    source "${home}/config.cfg"
else
    printf "Please create %s, and set at least STEAMUSER and STEAMPASS \n" "${home}/config.cfg"
fi

# download mods if parameter is set
if [ ! -d "$home"/mods ]; then
        printf "Could not find %s/mods \n" "$home"
        exit 1
    fi

if [ -z "${FTP_TARGET_USER}" ]; then
    printf "FTP_TARGET_USER is not set, please configure in config.cfg"
    exit 1
elif [ -z "${FTP_PASS_ENCRYPTED}" ]; then
    printf "FTP_PASS_ENCRYPTED is not set, please configure in config.cfg"
    exit 1
elif [ -z "${FTP_TARGET}" ]; then
    printf "FTP_TARGET is not set, please configure in config.cfg"
    exit 1
fi

sync_dir=${home}/mods/
ftp_pass_decrypted=$(echo "${FTP_PASS_ENCRYPTED}"| openssl enc -a -d -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}" 2>/dev/null)

printf "%s Starting upload \n" "$(date +'%Y-%m-%d %H:%M:%S')"
lftp -e \'mirror -v -RL "$sync_dir"\' -u "$FTP_TARGET_USER","$ftp_pass_decrypted" "$FTP_TARGET"
