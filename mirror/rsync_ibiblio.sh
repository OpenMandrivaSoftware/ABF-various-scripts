#!/bin/sh
#This script sync local repo from abf-downloads to a mirror

MIRNAME=ibiblio.org

# directory repo base
REPO=/home/abf-downloads

# directories and files to sync
SYNC="$HOME"/mirrors/sync

# excludes file - this contains a wildcard pattern per line of files to exclude
FILTERS="$HOME"/mirrors/filters

# the path of the mirror
MIRROR=SET_LOGIN_HERE@login.ibiblio.org:openmandriva

########################################################################

OPTS="-arvqH --delete --exclude-from=$FILTERS --files-from=$SYNC"

# the transfer
printf '%s\n' "START:" > /root/mirrors/$MIRNAME.log
date -u >> /root/mirrors/"$MIRNAME".log
rsync "$OPTS" "$REPO" "$MIRROR" --rsh="ssh -i /root/mirrors/key" >> /root/mirrors/"$MIRNAME".log
printf '%s\n' "END:" >> /root/mirrors/"$MIRNAME".log
date -u >> /root/mirrors/"$MIRNAME".log
