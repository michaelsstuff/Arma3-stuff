#!/bin/bash
a3_dir="/home/steam/arma3server"
yum install -y glibc libstdc++ glibc.i686 libstdc++.i686 wget
useradd -m steam
cd /home/steam/ || exit
curl -sL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
./steamcmd.sh +login anonymous +quit
if [ ! -d  $a3_dir ]; then
  if ! mkdir -p $a3_dir; then
    printf "Could not create %s \n" $a3_dir
    exit 1
  fi
fi
curl -sL https://raw.githubusercontent.com/michaelsstuff/arma3-server-scripts/master/server.sh -o server.sh
curl -sL https://raw.githubusercontent.com/michaelsstuff/arma3-server-scripts/master/hc.sh -o hc.sh
if [ ! -f  $a3_dir/config.cfg ]; then
  curl -sL https://raw.githubusercontent.com/michaelsstuff/arma3-server-scripts/master/config.cfg -o config.cfg
fi
chmod +x server.sh hc.sh
chown -R steam:steam /home/steam/
cat <<EOF > /etc/systemd/system/arma3-server.service
[Unit]
Description=Arma 3 Server
Requires=network

[Service]
ExecStart=/home/steam/server.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-server.service
cat <<EOF > /etc/systemd/system/arma3-hc.service
[Unit]
Description=Arma 3 Headless Client

[Service]
ExecStart=/home/steam/hc.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-hc.service
systemctl daemon-reload
printf "\n"
printf "You can now start the server with \'systemctl start arma3-server.service\' \n"
printf "Or you can start the headless client with \'systemctl start arma3-hc.service\' \n"
printf "\n"
printf "The initial start will take some time, as we have to download arma3 server\n"
printf "\n"
printf "Make sure to edit the /home/steam/config.cfg to match your requirements! \n"
printf "\n"
