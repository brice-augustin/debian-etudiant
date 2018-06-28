#!/bin/bash

PROXYIUT="proxy.iutcv.fr"
PROXYIUT_PORT="3128"

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
  # Trouver automatiquement la dernière version disponible
  v=$(apt-cache search virtualbox- | cut -d' ' -f1 | cut -d'-' -f2 | sort -V | tail -n 1)
  echo "Installation de virtualbox-$v"
  apt-get install -y virtualbox-$v

  ####
  # Packages
  # P
  ####
  #Firefox, Open Office
  apt-get install -y sudo
  apt-get install -y wireshark
  apt-get install -y openssh-server filezilla
  apt-get install -y evince shutter
fi

####
# Packages
# P+VM
####
apt-get install -y tcpdump
apt-get install -y net-tools iperf iptraf bridge-utils
apt-get install -y netcat
apt-get install -y exfat-fuse

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

echo "export http_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc
echo "export https_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc
echo "export ftp_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc

echo "Acquire::http::Proxy \"http://$PROXYIUT:$PROXYIUT_PORT\";" > /etc/apt/apt.conf.d/80proxy

if [ "$DEPLOY_TYPE" != "vm" ]
then
  ####
  # Proxy du navigateur Web
  # P
  ####

  # https://support.mozilla.org/fr/questions/901549
  # network.proxy.share_proxy_settings = true pour configurer le proxy HTTP pour
  # tous les autres protocoles
  # pref("network.proxy.ssl", "$PROXYIUT");
  # pref("network.proxy.ssl_port", "$PROXYIUT_PORT");
  # pref("network.proxy.ftp", "$PROXYIUT");
  # pref("network.proxy.ftp_port", "$PROXYIUT_PORT");
  cat > /usr/lib/firefox-esr/defaults/pref/local-settings.js << EOF
pref("network.proxy.http", "$PROXYIUT");
pref("network.proxy.http_port", $PROXYIUT_PORT);
pref("network.proxy.share_proxy_settings", true);
pref("network.proxy.no_proxies_on", "localhost,127.0.0.1,172.16.0.0/24,*.iutcv.fr");
pref("network.proxy.type", "1");
EOF


  ####
  # Verrouillage numérique
  # P
  ####
  echo "TODO setleds"
fi

####
# SSH
# P+VM
####
# Désactiver la connexion SSH avec le login root
# (activé pour provisionner une VM packer)
sed -i '/^PermitRootLogin/s/^/#/' /etc/ssh/sshd_config

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
ExecStart=/sbin/ifup-hook.sh start
ExecStop=
ExecStop=/sbin/ifup-hook.sh stop
EOF

# Reload les unités pour prendre en compte nos modifications
systemctl daemon-reload

####
# Grub
# P
####
# TODO : le faire dans un chroot à partir de Restore Hope
if [ "$DEPLOY_TYPE" != "vm" ]
then
  # Configurer grub.cfg pour qu'os_prober (sur Restore Hope) ajoute
  # la bonne entrée
  apt-get install -y grub-efi-amd64

  if ! grep "^GRUB_CMDLINE_LINUX=.*net.ifnames=0" /etc/default/grub > /dev/null 2>&1
  then
    sed -i '/GRUB_CMDLINE_LINUX/s/"$/ net.ifnames=0 biosdevname=0"/' /etc/default/grub
  fi

  sed -i '/GRUB_DISABLE_RECOVERY=/s/^.*$/GRUB_DISABLE_RECOVERY=true/' /etc/default/grub

  echo "GRUB_DISABLE_SUBMENU=y" >> /etc/default/grub

  # Ne pas ajouter d'entrée "setup" pour EFI
  chmod a-x /etc/grub.d/30_uefi-firmware
  # Ne pas prober les autres OS
  chmod a-x /etc/grub.d/30_os-prober

  # Génère une unique entrée (pour le Debian etudiant)
  update-grub

  cp /boot/grub/grub.cfg /root/grub.cfg

  apt-get remove -y --purge grub*

  # Copier grub.cfg généré précédemment
  mkdir -p /boot/grub
  cp /root/grub.cfg /boot/grub
fi

####
# Préparation au clonage ou à l'exportation OVA
# P+VM
####
cd prep
./masterprep.sh
