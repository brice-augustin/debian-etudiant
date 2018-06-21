#!/bin/bash

echo "auto lo" > /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces

ethif=$(ip -o l show | awk -F': ' '{print $2}' | grep "^eth")

# /sys/class/net/eth0/operstate (up ou down)
for iface in $ethif
do
  echo "auto $iface" >> /etc/network/interfaces
  echo "iface $iface inet dhcp" >> /etc/network/interfaces
done

echo "# GLOP" >> /etc/network/interfaces
echo "#" $(date) >> /etc/network/interfaces

systemctl disable init-interfaces.service
