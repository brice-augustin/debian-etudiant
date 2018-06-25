#!/bin/bash

# ifquery --list : only interfaces marked as auto in config file
ethif=$(ip -o l show | awk -F': ' '{print $2}' | grep "^eth")

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
