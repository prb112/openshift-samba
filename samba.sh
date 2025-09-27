#!/usr/bin/env bash

echo "Creating Samba users"
adduser --no-create-home --no-user-group USERNAME -p PASSWORD
yes PASSWORD | smbpasswd -a USERNAME

echo "Starting Samba 4"
ionice -c 3 smbd --foreground --debug-stdout --no-process-group < /dev/null