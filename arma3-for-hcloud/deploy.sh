#!/bin/bash
# shellcheck disable=SC2140
# shellcheck source=config.cfg
# shellcheck disable=SC1091
docker build -t arma3-hetzner/deploy .
hcloud="docker run -it --env-file .env arma3-hetzner/deploy:latest"
source "config.cfg"

if [ ! -f ssh.key ]; then
    ssh-keygen -t rsa -N "" -f ssh.key
fi

if ! $hcloud ssh-key list | grep "$(hostname)"; then
    pubkeystring=$(<ssh.key.pub)
    $hcloud ssh-key create --name "$(hostname)" --public-key "$pubkeystring"
fi

cryptkey=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

test_ssh() {
    ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -i ssh.key -q root@"$1" exit
}

create_hc() {
    declare -a hclients
    for i in $(seq 1 "$NR_HC"); do
        $hcloud server create --image centos-7 --name HC-"$i" --type cx31 --ssh-key "$(hostname)"
        ip="$($hcloud server list -o noheader | grep HC-"$i"  | awk '{print $4}')"
        hclients+=("$ip")
        sleep 10
        n=0
        until [ $n -ge 3 ]; do
            test_ssh "$ip" && break
            n=$((n+1))
        done
        declare steamu
        eval steamu="$"STEAMUSER"$i"
        declare steamp
        eval steamp="$"STEAMPASS"$i"
        ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -i ssh.key root@"$ip" << EOC
curl https://raw.githubusercontent.com/michaelsstuff/arma3-server-scripts/master/install.sh | bash
cat <<EOF >  /home/steam/config.cfg
MODURL="ftp://158.69.123.76/"
SERVER="158.69.123.76"
SERVERPASS="Fight21"
STEAMUSER="$steamu"
STEAMPASS="$steamp"
home="/home/steam"
a3_dir="/home/steam/arma3server"
#NOBASIC=true
MODUPDATE=true

EOF
systemctl start arma3-hc.service
systemctl status arma3-hc.service
EOC
    done
}

create_server() {
    $hcloud server create --image centos-7 --name arma3server --type ccx21 --ssh-key "$(hostname)"
    ip="$($hcloud server list -o noheader | grep arma3server  | awk '{print $4}')"
    sleep 10
    n=0
    until [ $n -ge 3 ]; do
        test_ssh "$ip" && break
        n=$((n+1))
    done
    declare steamu
    eval steamu="$"STEAMUSER"server"
    declare steamp
    eval steamp="$"STEAMPASS"server"
    list1=$( IFS=$', '; echo "${hclients[*]}" )
    headlessClients=$(echo "$list1" | sed 's/,/","/g' | awk '{print "\""$0}' | awk '{print $0"\""}')
    ssh -o PreferredAuthentications=publickey -o StrictHostKeyChecking=no -i ssh.key root@"$ip" << EOC
yum install git -y
git clone https://github.com/michaelsstuff/Arma3-stuff.git
cd Arma3-stuff/a3-server/
bash install.sh -s
echo "$cryptkey" > /home/steam/secret.key
sed -i "/STEAMUSER=/c\STEAMUSER=\"${steamu}\" /home/steam/config.cfg
sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAMPASS_new_crypted}\"" "$steam_home"config.cfg

sed -i "/MODUPDATE=/c\MODUPDATE=workshop" "$steam_home"config.cfg
sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAMWSUSER}\"" "$steam_home"config.cfg
sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAMWSPASS_new_crypted}\"" "$steam_home"config.cfg
sed -i "/WS_IDS=/c\WS_IDS=(${ws_ids[*]})" "$steam_home"config.cfg

curl -sL https://raw.githubusercontent.com/michaelsstuff/Arma3-stuff/master/a3-server/server.cfg -o "/home/steam/arma3server/server.cfg


cat <<EOF >  /home/steam/arma3server/server.cfg
hostname       = "My Arma 3 Server";
password     = "$SERVERPASS";
passwordAdmin  = "$SERVERADMINPASS";
maxPlayers     = "$MAXPLAYERS";
persistent     = "$PERSISTENT";
disableVoN       = 1;
vonCodecQuality  = 30;
voteMissionPlayers  = 1;
voteThreshold       = 0.33;
allowedVoteCmds[] =            // Voting commands allowed to players
{
	// {command, preinit, postinit, threshold} - specifying a threshold value will override "voteThreshold" for that command
	{"admin", false, false}, // vote admin
	{"kick", false, true, 0.51}, // vote kick
	{"missions", false, false}, // mission change
	{"mission", false, false}, // mission selection
	{"restart", false, false}, // mission restart
	{"reassign", false, false} // mission restart with roles unassigned
};
class Missions
{
	class Mission1
	{
		template = "MyMission.Altis"; // Filename of pbo in MPMissions folder
		difficulty = "Regular"; // "Recruit", "Regular", "Veteran", "Custom"
	};
};
BattlEye             = 1;
verifySignatures     = 2;
kickDuplicate        = 1;
allowedFilePatching  = 1;
allowedLoadFileExtensions[] =       {"hpp","sqs","sqf","fsm","cpp","paa","txt","xml","inc","ext","sqm","ods","fxy","lip","csv","kb","bik","bikb","html","htm","biedi"}; // only allow files with those extensions to be loaded via loadFile command (since Arma 3 v1.19.124216) 
allowedPreprocessFileExtensions[] = {"hpp","sqs","sqf","fsm","cpp","paa","txt","xml","inc","ext","sqm","ods","fxy","lip","csv","kb","bik","bikb","html","htm","biedi"}; // only allow files with those extensions to be loaded via preprocessFile / preprocessFileLineNumbers commands (since Arma 3 v1.19.124323)
allowedHTMLLoadExtensions[] =       {"htm","html","php","xml","txt"}; // only allow files and URLs with those extensions to be loaded via htmlLoad command (since Arma 3 v1.27.126715)
onUserConnected     = "";    // command to run when a player connects
onUserDisconnected  = "";    // command to run when a player disconnects
doubleIdDetected    = "";    // command to run if a player has the same ID as another player in the server
onUnsignedData      = "kick (_this select 0)";    // command to run if a player has unsigned files
onHackedData        = "kick (_this select 0)";    // command to run if a player has tampered files
headlessClients[]  = { $headlessClients };
localClient[]      = {"127.0.0.1"};

EOF

systemctl start arma3-hc.service
sleep 3
systemctl status arma3-hc.service
EOC
}

remove_all() {
    for i in $(seq 1 "$NR_HC"); do
        $hcloud server delete HC-"$i"
    done
}

if ! [[ "$NR_HC" =~ ^[0-9]+$ ]]
    then
        printf "\"NR_HC\" does not appear to be a integer. Will skip Headless Client deployment \n"
    else
        create_hc
fi
