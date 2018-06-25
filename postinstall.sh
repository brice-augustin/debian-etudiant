#!/bin/bash

PROXYIUT="http://proxy.iutcv.fr:3128"

if [ $EUID -ne 0 ]
then
  echo "Doit être exécuté en tant que root"
  exit
fi

# TODO : utiliser facter pour savoir si on est sur une VM ou un PC physique

if [ "$DEPLOY_TYPE" == "vm" ]
then
  sleep 5
fi

apt-get update -y

if [ "$DEPLOY_TYPE" != "vm" ]
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

  wget --no-check-certificate https://www.virtualbox.org/download/oracle_vbox_2016.asc
  apt-key add oracle_vbox_2016.asc

  apt-get update -y
  # 734 Mo en plus
  # TODO : trouver automatiquement la dernière version disponible
  # apt-cache search virtualbox-
  apt-get install -y virtualbox-5.2

  ####
  # Packages
  # P
  ####
  #Firefox, Open Office
  apt-get install -y sudo
  apt-get install -y wireshark
  apt-get install -y openssh-server filezilla
  apt-get install -y  evince shutter
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

# Effacer toute config de *_proxy
sed -E -i '/(ht|f)tps?_proxy=/d' /etc/bash.bashrc

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

if [ "$DEPLOY_TYPE" != "vm" ]
then
  ####
  # Proxy du navigateur Web
  # P
  ####
  # TODO : navigateur Web
  echo "TODO proxy pour le navigateur"

  ####
  # Verrouillage numérique
  # P
  ####
  echo "TODO setleds"
fi

# TODO : Effacer /var/cache/apt/archives

# TODO : Timeout /etc/dhcp/dhclient.conf ?

####
# ifupdown
# P+VM
####

# Perdu 2 heures parce que sed détruit le lien symbolique vers /lib/systemd/system/...
# https://unix.stackexchange.com/questions/192012/how-do-i-prevent-sed-i-from-destroying-symlinks
# De toute façon, il y a mieux (drop-in)
#sed -i --follow-symlinks 's/^ExecStart=.*$/ExecStart=\/sbin\/ifup-hook.sh/' /etc/systemd/system/network-online.target.wants/networking.service

cp prep/ifup-hook.sh /sbin

# Bug: Cannot edit units if not on a tty
#SYSTEMD_EDITOR=tee systemctl edit networking.service << EOF
#...

# Mécanisme override de systemctl
mkdir /etc/systemd/system/networking.service.d/
cat > /etc/systemd/system/networking.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/sbin/ifup-hook.sh
EOF

# Reload les unités pour prendre en compte nos modifications
systemctl daemon-reload

####
# Préparation au clonage ou à l'exportation OVA
# P+VM
####
cd prep
./masterprep.sh
