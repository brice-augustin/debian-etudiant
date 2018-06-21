#!/bin/bash

sleep 5

PROXYIUT="http://proxy.iutcv.fr:3128"

echo vitrygtr | sudo -S apt-get update

#sudo su

sudo apt-get install -y dnsutils

####
# Interfaces
####
# Configuration dynamique persistante pour toutes les cartes

echo "auto lo" | sudo tee /etc/network/interfaces
echo "iface lo inet loopback" | sudo tee -a /etc/network/interfaces

ethif=$(ip -o l show | awk -F': ' '{print $2}' | grep "^eth")

for iface in $ethif
do
  echo "auto $iface" | sudo tee -a /etc/network/interfaces
  echo "iface $iface inet dhcp" | sudo tee -a /etc/network/interfaces
done

####
# Proxy
# P+VM
####
# Alternative : ajouter ça dans /etc/profile.d/proxy.sh
# sudo cmd > fich : permission denied car la redirection est effectuée par le shell
# avec les droits de l'utilisateur courant.
# Utiliser tee (pour >) ou tee -a (pour >>)
# https://blog.sleeplessbeastie.eu/2013/12/03/how-to-redirect-command-output-using-sudo/
echo "http_proxy=$PROXYIUT" | sudo tee -a /etc/bash.bashrc
echo "https_proxy=$PROXYIUT" | sudo tee -a /etc/bash.bashrc
echo "ftp_proxy=$PROXYIUT" | sudo tee -a /etc/bash.bashrc

echo "Acquire::http::Proxy \"$PROXYIUT\";" | sudo tee /etc/apt/apt.conf.d/80proxy
