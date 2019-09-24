#!/bin/bash

#echo $@

MAX_LINKUP_WAIT=5

# Récupérer le nom de la carte réseau à configurer
# (dernier paramètre de dhclient -- XXX toujours le cas ?)
nic=$(echo $@ | awk '{print $NF}')

# dhclient peut être invoqué sans paramètre
if [ "$nic" != "" ]
then
  # Activer l'interface
  ip l set dev $nic up

  # Abandonner après MAX_LINKUP_WAIT secondes
  c=$MAX_LINKUP_WAIT
  while [ $c -gt 0 ]
  do
    # Attendre qu'elle soit initialisée
    if ip a s dev $nic | grep 'state UP' &> /dev/null
    then
      break
    fi
    echo -n "."
    sleep 1
    c=$(($c - 1))
  done
fi

echo ""

# Inutile mais fun
args=$(echo $@ | awk '{$NF=""; print $0}')

#if [ $c -eq 0 ]
#then
# --timeout does not exist; see dhclient.conf
#  args="$args --timeout 30"
#fi

# L'interface est initialisée, le dhclient legacy peut faire
# son travail dans de bonnes conditions
/usr/sbin/dhclient.legacy $args $nic
