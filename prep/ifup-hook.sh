#!/bin/bash

# Solution 1 : lancer ifup en tâche de fond

if [ "$1" == "start" ]
then
  /sbin/ifup -a --read-environment &
else
  /sbin/ifdown -a --read-environment --exclude=lo &
fi

exit

# Solution 2 : lancer ifup slt sur les cartes avec un câble branché.
# Problème : obligation de faire ifup manuel après le branchement du câble
# Problème : sleep 1 pas suffisant pour que le système détecte la présence
# du câble

# ifquery --list : only interfaces marked as auto in config file
# Accepter le nouveau nommage des cartes (en) mais aussi l'ancien (eth)
ethif=$(ip -o l show | awk -F': ' '{print $2}' | grep -E "^(eth|en)")

for iface in $ethif
do
  ip l set $iface up
done

# Let the system activate the NIC
sleep 1

for iface in $ethif
do
  # Cable connected
  if grep up /sys/class/net/$iface/operstate > /dev/null 2>&1
  then
    # $iface might not exist in interfaces file. Don't care.
    /sbin/ifup $iface --read-environment
  fi
done
