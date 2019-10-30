#!/bin/bash
yum install vsftpd -y

systemctl enable vsftpd

cat <<EOF >/etc/vsftpd/vsftpd.conf

listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
local_root=/var/www
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES

#virutal user settings
user_config_dir=/etc/vsftpd_user_conf
guest_enable=YES
virtual_use_local_privs=YES
pam_service_name=vsftpd
nopriv_user=vsftpd
guest_username=vsftpd

EOF

cat <<EOF >/etc/pam.d/vsftpd
auth required pam_pwdfile.so pwdfile /etc/vsftpd/ftpd.passwd
account required pam_permit.so

EOF

mkdir /etc/vsftpd_user_conf


cat <<EOF >/etc/vsftpd_user_conf/steam
local_root=/home/steam/arma3server/mpmissions

EOF

useradd --home /home/vsftpd --gid steam -m --shell /bin/false vsftpd

chown vsftpd:steam /home/steam/arma3server/mpmissions


systemctl start vsftpd


