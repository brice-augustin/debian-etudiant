#!/bin/bash

PROXYIUT="http://proxy.iutcv.fr:3128"

# facter

if [ $DEPLOY_TYPE == "vm" ]
then
  sleep 5
fi

apt-get update -y

if [ $DEPLOY_TYPE != "vm" ]
then
  ####
  # Network manager
  # P
  ####
  apt-get remove --purge network-manager
  if dpkg -l wicd | grep -E "ii\s+wicd"
  then
    apt-get remove --purge wicd
  fi

  ####
  # VirtualBox
  # P
  ####
  echo "deb http://download.virtualbox.org/virtualbox/debian stretch contrib" > /etc/apt/sources.list.d/virtualbox.list

  wget https://www.virtualbox.org/download/oracle_vbox_2016.asc
  apt-key add oracle_vbox_2016.asc

  apt-get update -y
  # 651 Mo en plus
  apt-get install -y virtualbox-5.1

  ####
  # Packages
  # P
  ####
  #Firefox, Open Office
  apt-get install -y sudo
  apt-get install -y wireshark
  apt-get install -y openssh-server filezilla
  apt-get install -y  evince
fi

####
# Packages
# P+VM
####
apt-get install -y tcpdump
apt-get install -y net-tools iperf iptraf bridge-utils
apt-get install -y netcat

####
# sudo
# P+VM
####
adduser etudiant sudo

####
# Proxy
# P+VM
####
# Alternative : ajouter ça dans /etc/profile.d/proxy.sh
echo "http_proxy=$PROXYIUT" >> /etc/bash.bashrc
echo "https_proxy=$PROXYIUT" >> /etc/bash.bashrc
echo "ftp_proxy=$PROXYIUT" >> /etc/bash.bashrc

echo "Acquire::http::Proxy \"$PROXYIUT\";" > /etc/apt/apt.conf.d/80proxy

####
# SSH
# P+VM
####
# Désactiver la connexion SSH avec le login root
# (activé pour provisionner une VM packer)
sed -i '/^PermitRootLogin/s/^/#/' /etc/ssh/sshd_config

if [ $DEPLOY_TYPE != "vm" ]
then
  ####
  # Proxy du navigateur Web
  # P
  ####
  # TODO : navigateur Web
  echo "TODO"

  ####
  # Verrouillage numérique
  # P
  ####

  ####
  # Préparation du master
  # (script d'init interfaces au démarrage, udev persistent-net)
  ####
fi

# Effacer /var/cache/apt/archives

cd prep
./masterprep.sh
