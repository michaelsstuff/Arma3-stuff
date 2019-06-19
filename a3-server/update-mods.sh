#!/bin/bash

if [ -f .secrets ]; then
  # shellcheck disable=SC1091
  source .secrets
else
  printf "Please create a .secrets file with githubuser and githubtoken"
  exit 1
fi

home="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
moddir="${home}/arma3server/mods/"
update_list="${home}/arma3server/modupdate.latest" 

if [ -f "$home/config.cfg" ]; then
# shellcheck source=config.cfg
# shellcheck disable=SC1091
  source "$home/config.cfg"
fi

declare -A versions
if [ -f "$update_list" ]; then
    # shellcheck disable=SC1090
    source "$update_list"
fi

# compare versions
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

# CBA3
cba3_version="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/CBATeam/CBA_A3/releases/latest | jq -r .tag_name)"
if [ -n "$cba3_version" ]; then
  if version_lt "${versions[cba]}" "$cba3_version"; then
    printf "CBA has newer version %s - updating .... \n" "$cba3_version"
    cba3_url="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/CBATeam/CBA_A3/releases/latest | jq -r .assets[].browser_download_url)"
    curl -L -s "$cba3_url" -o cba3.zip
    modname_dir="$(unzip -Ll cba3.zip  | awk 'NR==4{print $4;}' | tr -d ^)"
    rm -fr "$moddir""$modname_dir"
    unzip -qCL cba3.zip -d "$moddir"
    rm -f cba3.zip
    versions[cba]="$cba3_version"
  else
    printf "CBA is up to date - %s \n" "${versions[cba]}"
  fi
fi

# ACE3
ace3_version="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/acemod/ACE3/releases/latest | jq -r .tag_name)"
if [ -n "$ace3_version" ]; then
  if version_lt "${versions[ace3]}" "$ace3_version"; then
    printf "ACE3 has newer version %s - updating .... \n" "$ace3_version"
    ace3_url="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/acemod/ACE3/releases/latest | jq -r .assets[].browser_download_url)"
    curl -L -s "$ace3_url" -o ace3.zip
    modname_dir="$(unzip -Ll ace3.zip  | awk 'NR==4{print $4;}' | tr -d ^)"
    rm -fr "$moddir""$modname_dir"
    unzip -qCL ace3.zip -d "$moddir"
    rm -f ace3.zip
    versions[ace3]="$ace3_version"
  else
    printf "ACE3 is up to date - %s \n" "${versions[ace3]}"
  fi
fi

# ACEX
acex_version="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/acemod/ACEX/releases/latest | jq -r .tag_name)"
if [ -n "$acex_version" ]; then
  if version_lt "${versions[acex]}" "$acex_version"; then
    printf "ACEX has newer version %s - updating .... \n" "$acex_version"
    acex_url="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/acemod/ACEX/releases/latest | jq -r .assets[].browser_download_url)"
    curl -L -s "$acex_url" -o acex.zip
    modname_dir="$(unzip -Ll acex.zip  | awk 'NR==4{print $4;}' | tr -d ^)"
    rm -fr "$moddir""$modname_dir"
    unzip -qCL acex.zip -d "$moddir"
    rm -f acex.zip
    versions[acex]="$acex_version"
  else
    printf "acex is up to date - %s \n" "${versions[acex]}"
  fi
fi

# acre2
acre2_version="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/IDI-Systems/acre2/releases/latest | jq -r .tag_name)"
if [ -n "$acre2_version" ]; then
  if version_lt "${versions[acre2]}" "$acre2_version"; then
    printf "acre2 has newer version %s - updating .... \n" "$acre2_version"
    acre2_url="$(curl -u "$githubuser":"$githubtoken" -s https://api.github.com/repos/IDI-Systems/acre2/releases/latest | jq -r .assets[].browser_download_url)"
    curl -L -s "$acre2_url" -o acre2.zip
    modname_dir="$(unzip -Ll acre2.zip  | awk 'NR==4{print $4;}' | tr -d ^)"
    rm -fr "$moddir""$modname_dir"
    unzip -qCL acre2.zip -d "$moddir"
    rm -f acre2.zip
    versions[acre2]="$acre2_version"
  else
    printf "acre2 is up to date - %s \n" "${versions[acex]}"
  fi
fi

declare -p  versions > "$update_list"
