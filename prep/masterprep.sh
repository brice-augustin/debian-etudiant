#!/bin/bash

####
# Anciens noms de cartes réseau (eth0, pas ens33 ou enp0s3)
# # https://www.itzgeek.com/how-tos/linux/debian/change-default-network-name-ens33-to-old-eth0-on-debian-9.html
# P (VM fait automatiquement)
####

# Lire /proc/cmdline pour savoir quel nommage est utilisé
if ! grep net.ifnames=0 /proc/cmdline > /dev/null 2>&1
then
  # Retirer le debian-installer (change la resolution par défaut)
  #sed -i -E '/GRUB_CMDLINE_LINUX/s/debian-installer=[^ "]+//' /etc/default/grub

  # ajouter net.ifnames=0 biosdevname=0
  sed -i '/GRUB_CMDLINE_LINUX/s/"$/ net.ifnames=0 biosdevname=0"/' /etc/default/grub

  # ou update-grub
  grub-mkconfig -o /boot/grub/grub.cfg
fi

####
# Configuration des interfaces au prochain reboot
# P+VM
####
# Copier script dans /etc/... qui s'exécute au boot et se supprime
cp init-interfaces.sh /usr/local/bin

cat > /etc/systemd/system/init-interfaces.service << EOF
[Unit]
Description=Configuration du fichier interfaces au premier boot

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/local/bin/init-interfaces.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable init-interfaces.service

####
# Empecher renommage des cartes réseau lors du clonage
# P
####
# N'existe plus sous stretch ?
# /etc/udev/rules.d/70-persistent-net.rules

####
# Désinstaller Grub
# P
####
if [ "$DEPLOY_TYPE" != "vm" ]
then
  echo "TODO : uninstall grub"
  apt-get remove --purge grub*
fi
