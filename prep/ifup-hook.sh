#!/bin/bash

ethif=$(/sbin/ifquery --list | grep ^eth)

for iface in $ethif
do
  ip l set $iface up
done

# Let the system activate the NIC
sleep 5

for iface in $ethif
do
  # Cable connected
  if grep up /sys/class/net/$iface/operstate > /dev/null 2>&1
  then
    /sbin/ifup $iface --read-environment
  fi
done
