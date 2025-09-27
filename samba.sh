#!/usr/bin/env bash

echo "Creating Samba users"
adduser -s /sbin/nologin -h /home/samba -H -D USERNAME
yes PASSWORD | smbpasswd -a USERNAME

echo "Starting Samba 4"
ionice -c 3 smbd --foreground --log-stdout --no-process-group < /dev/null