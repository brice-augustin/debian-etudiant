#!/bin/bash

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
