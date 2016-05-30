#!/usr/bin/env bash

set -e

# php session
mkdir -m 777 -p /srv/php/session
echo "tmpfs /srv/php/session tmpfs size=32m,mode=700,uid=www-data,gid=www-data 0 0" >> /etc/fstab
mount /srv/php/session # need docker to run with "--privileged" option
# php upload_tmp_dir
mkdir -m 777 -p /srv/php/upload_tmp_dir

# execute pre shell files
test -f /usr/local/bin/pre01.sh && chmod +x /usr/local/bin/pre01.sh && /usr/local/bin/pre01.sh
test -f /usr/local/bin/pre02.sh && chmod +x /usr/local/bin/pre02.sh && /usr/local/bin/pre02.sh

#
# Run container foreground
#

# supervisor
/usr/bin/supervisord
