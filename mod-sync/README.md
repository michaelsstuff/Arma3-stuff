# workshop.sh

Create a cryptokey to store the passwords:

`< /dev/urandom hexdump -n 16 -e '4/4 "%08X" 1 "\n"'`

Encrypt your steampassword:

`echo "yourpassword" | openssl enc -a -e -aes-256-cbc -md md5 -pass pass:"${CRYPTKEY}"`

create a config.sh in /home/steam/

```cfg
CRYPTKEY=""
STEAMUSER=""
STEAMPASS=""
WSCOLLECTIONID=
```

Instead of WSCOLLECTIONID you can also make a list yourself:

```cfg
WS_IDS=(450814997 463939057 708250744 751965892)
```

This script expects steamcmd and to be run as user `steam`

```bash
/home/steam/workshop.sh
```
