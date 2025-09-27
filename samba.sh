#!/usr/bin/env bash

echo "Creating Samba users"
adduser --home-dir /export/smbshare --no-user-group USERNAME -p PASSWORD
yes PASSWORD | smbpasswd -a USERNAME

echo "Starting Samba 4"
ionice -c 3 smbd --foreground --debug-stdout --no-process-group < /dev/null