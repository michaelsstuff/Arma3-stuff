FROM wilkesystems/steamcmd:centos7
RUN yum install -y lftp openssl
RUN useradd -m steam
USER steam
WORKDIR /home/steam

/home/steam/.steam/