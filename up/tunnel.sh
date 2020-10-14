#!/usr/bin/env bash
BRIDGE_IP=`terraform output bridge_ip`
/app/up/wait-for-it.sh $REDIRECT_TO

/app/up/wait-for-it.sh $BRIDGE_IP:2222

autossh -M 0 -- -v -f -N \
-i private-ssh-key \
-o ServerAliveCountMax=3 -o ServerAliveInterval=60 -o StrictHostKeyChecking=no \
-R *:8080:$REDIRECT_TO -p 2222 bridge@$BRIDGE_IP
