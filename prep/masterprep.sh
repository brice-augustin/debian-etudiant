#!/bin/bash

#########
# Script commun à Debian etudiant et RH
#########

####
# Proxy
####
cp proxy.sh /usr/sbin/

p=$(grep "^Acquire::http::Proxy" /etc/apt/apt.conf 2> /dev/null | cut -d'"' -f 2)

# Si l'install a été faite avec le proxy, activer sa configuration complète
if [ "$p" != "" ]
#if [ "$PROXYIUT" != "" ]
then
  /usr/sbin/proxy.sh enable force
fi

####
# setleds
####

# systemd, pas init
# https://wiki.archlinux.org/index.php/Activating_Numlock_on_Bootup#Using_a_separate_service
# Bug : Cannot edit units if not on a tty
#SYSTEMD_EDITOR=tee systemctl edit getty@.service << EOF

mkdir -p /etc/systemd/system/getty\@.service.d

cat > /etc/systemd/system/getty\@.service.d/override.conf << EOF
[Service]
ExecStartPre=/bin/sh -c 'setleds -D +num < /dev/%I'
EOF

####
# Configuration des interfaces au prochain reboot
# P+VM
####

# Copier script dans /etc/... qui s'exécute au boot et se supprime
cp init-interfaces.sh /usr/local/bin

cat > /etc/systemd/system/init-interfaces.service << EOF
[Unit]
Description=Configuration du fichier interfaces au premier boot
Before=networking.service

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/local/bin/init-interfaces.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable init-interfaces.service

####
# ifupdown
# P+VM
####

# Perdu 2 heures parce que sed détruit le lien symbolique vers /lib/systemd/system/...
# https://unix.stackexchange.com/questions/192012/how-do-i-prevent-sed-i-from-destroying-symlinks
# De toute façon, il y a mieux (drop-in)
#sed -i --follow-symlinks 's/^ExecStart=.*$/ExecStart=\/sbin\/ifup-hook.sh/' /etc/systemd/system/network-online.target.wants/networking.service

cp ifup-hook.sh /sbin

# Bug: Cannot edit units if not on a tty
#SYSTEMD_EDITOR=tee systemctl edit networking.service << EOF
#...

# Mécanisme override de systemctl
mkdir -p /etc/systemd/system/networking.service.d/
cat > /etc/systemd/system/networking.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/sbin/ifup-hook.sh start
ExecStop=
ExecStop=/sbin/ifup-hook.sh stop
EOF

# Reload les unités pour prendre en compte nos modifications
# "Running in chroot, ignoring request." si lancé depuis chroot
systemctl daemon-reload

####
# Hook pour dhclient
# P+VM
####

# Do not install the hook if it's already in place (infinite loop) !
if [ ! -f /usr/local/sbin/dhclient ]
then
  # Faire une copie du dhclient legacy
  mv /sbin/dhclient /sbin/dhclient.legacy
  # Dans Buster, dhclient est aussi dans /usr/sbin (en plus de /sbin)
  # /usr/sbin est un miroir de /sbin !
  # Pas besoin de renommer /usr/sbin/dhclient, c'est déjà fait avec le précédent
  # mv /usr/sbin/dhclient /usr/sbin/dhclient.legacy

  # Notre hook doit obligatoirement être dans /sbin (codé en dur dans ifup).
  # Il invoque le dhclient legacy via son 'nouveau' chemin complet
  cp dhclient-hook.sh /sbin/dhclient
  # Pas besoin, /usr/sbin est un miroir de /sbin
  #ln /sbin/dhclient /usr/sbin

  # Au cas où une autre app (ou un utilisateur) invoque dhclient
  # sans préciser le chemin, il faut que notre hook soit invoqué.
  # /usr/local/sbin est en premier dans le PATH du root :
  # /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  ln /sbin/dhclient /usr/local/sbin

  # dhclient doit abandonner après 10 secondes; évite qu'une interface non câblée
  # retarde la conf des interfaces suivantes pendant des plombes ...
  echo "timeout 10;" >> /etc/dhcp/dhclient.conf
fi

####
# Swap
# https://lists.debian.org/debian-user/2017/09/msg00866.html
####

if [ "$DEPLOY_TYPE" != "cli" ]
then
  # /dev/sda5 -> \/dev\/sda5 sinon sed couine
  swap=$(swapon -s | grep "^/dev" | awk '{print $1}' | sed 's/\//\\\//g')

  # TODO : remplacer par l'UUID du swap du Debian etudiant (ou l'inverse)
  sed -i -E "/ swap /s/^UUID=[^ ]+/$swap/" /etc/fstab

  echo "" > /etc/initramfs-tools/conf.d/resume

  update-initramfs -u
fi

####
# Empecher renommage des cartes réseau lors du clonage
# P
####
# N'existe plus sous stretch ?
# /etc/udev/rules.d/70-persistent-net.rules
