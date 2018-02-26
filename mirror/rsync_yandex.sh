#!/bin/sh
#This script sync local repo from abf-downloads to a mirror

MIRNAME=yandex.ru

# directory repo base
REPO=/home/abf-downloads

# directories and files to sync
SYNC="$HOME"/mirrors/sync

# excludes file - this contains a wildcard pattern per line of files to exclude
FILTERS="$HOME"/mirrors/filters

# the path of the mirror
MIRROR=rsync://pull-mirror.yandex.net/openmandriva-push/

########################################################################

OPTS="-arvqH --delete --exclude-from=$FILTERS --files-from=$SYNC"

# the transfer
printf '%s\n' "START:" > /root/mirrors/"$MIRNAME".log
date -u >> /root/mirrors/"$MIRNAME".log
rsync $OPTS "$REPO" "$MIRROR" >> /root/mirrors/"$MIRNAME".log
# yandex needs a .mirror.yandex.ru file for replicating on its mirrors 
date -u > /root/mirrors/.mirror."$MIRNAME"
rsync -vq /root/mirrors/.mirror."$MIRNAME" "$MIRROR" >> "$MIRNAME".log
printf '%s\n' "END:" >> /root/mirrors/"$MIRNAME".log
date -u >> /root/mirrors/"$MIRNAME".log
