#!/bin/bash
#
# Please fill out the following variables.
# Or edit the config.cfg
#
home="/home/steam"                # this could be overwritten by the config.cfg
a3_dir="/home/steam/arma3server"  # this could be overwritten by the config.cfg

# shellcheck source=config.cfg
source "$home/config.cfg"

# the following settings can be configured by the config.cfg above, or environment variables, or by enabling them here
#MODURL="ftp://xxx.xxx.xxx.xxx/"
#SERVER="xxx.xxx.xxx.xxx"
#SERVERPASS=""
#STEAMUSER=""
#STEAMPASS=""
#NOBASIC=true
#MODUPDATE=true
declare -a mods_array
pid=$$

if [ ! -d  "$a3_dir"/logs ]; then
  if ! mkdir -p "$a3_dir"/logs; then
    printf "Could not create %s/logs \n" "$a3_dir"
    exit 1
  fi
fi

# logging
TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"+%Y-%m-%d"}
LOGFILE=$a3_dir/logs/"arma3"_$(date "$TIMESTAMP_FORMAT")_PID-$pid.log
# Redirect stdout/stderr to tee to write the log file
exec > >(tee -a "${LOGFILE}") 2>&1

# check for required vars
if [ -z "$SERVER" ]; then
  printf "SERVER IP not given. Please check variables \n"
  exit 1
fi
if [ -z "$STEAMUSER" ]; then
  printf "Steam username not given. Please check variables \n"
  exit 1
fi
if [ -z "$STEAMPASS" ]; then
  printf "Steam Password not given. Please check variables \n"
  exit 1
fi

# download arma3 server
cd $home || exit
./steamcmd.sh +login "$STEAMUSER" "$STEAMPASS" +force_install_dir "$a3_dir" +app_update 233780 validate +quit

# check profile folder
if [ ! -d  $home"/.local/share/Arma 3" ]; then
  if ! mkdir -p $home"/.local/share/Arma 3"; then
    printf "Could not create %s'/.local/share/Arma 3' \n" $home
    exit 1
  fi
fi
if [ ! -d  $home"/.local/share/Arma 3 - Other Profiles" ]; then
  if ! mkdir -p $home"/.local/share/Arma 3 - Other Profiles"; then
    printf "Could not create %s'/.local/share/Arma 3 - Other Profiles' \n" $home
    exit 1
  fi
fi

# download mods if parameter is set
if [[ $MODUPDATE = "true" ]]; then
  wget -m -c --restrict-file-names=lowercase -P "$a3_dir"/mods/ -nH "${MODURL}"
fi

# create modlist
cd "$a3_dir" || exit
for d in mods/@*/ ; do
  mods_array+=("$d")
done
mods=$( IFS=$';'; echo "${mods_array[*]}" )

# getting tuned basic config, tuned for about 100 Mbit/s synchronous
if [[ $NOBASIC != "true" ]]; then
  curl -sL https://raw.githubusercontent.com/michaelsstuff/arma3-server-scripts/master/basic.cfg -o "$a3_dir"/basic.cfg
fi

# starting the headless client
cd "$a3_dir"/ || exit
./arma3server -connect="$SERVER" -port=2302 -password="$SERVERPASS" -cfg=basic.cfg -client -loadMissionToMemory -hugepages -bandwidthAlg=2 -mod=\""$mods"\"
