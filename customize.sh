#!/bin/bash

sleep 5

PROXYIUT="http://proxy.iutcv.fr:3128"

echo vitrygtr | sudo -S apt-get update

#sudo su

sudo apt-get install -y dnsutils

####
# Proxy
# P+VM
####
# Alternative : ajouter ça dans /etc/profile.d/proxy.sh
echo "http_proxy=$PROXYIUT" >> /etc/bash.bashrc
echo "https_proxy=$PROXYIUT" >> /etc/bash.bashrc
echo "ftp_proxy=$PROXYIUT" >> /etc/bash.bashrc

echo "Acquire::http::Proxy \"$PROXYIUT\";" > /etc/apt/apt.conf.d/80proxy

exit

####
# Anciens noms de cartes réseau (eth0, pas ens33 ou enp0s3)
####

if ! grep GRUB_CMDLINE_LINUX=\"\" /etc/default/grub > /dev/null 2>&1
then
  echo "GRUB_CMDLINE_LINUX non vide dans /etc/default/grub"
  # TODO: editer la variable proprement
  echo "Abandon"
  exit
fi

# https://www.itzgeek.com/how-tos/linux/debian/change-default-network-name-ens33-to-old-eth0-on-debian-9.html
sed -E -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
