#!/bin/bash

export PROXYIUT="proxy.iutcv.fr"
export PROXYIUT_PORT="3128"

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

####
# Préparation au clonage ou à l'exportation OVA
# Doit être lancé au début pour configurer le proxy
# P+VM
####
pushd prep
./masterprep.sh
popd

apt-get update -y

if [ "$DEPLOY_TYPE" != "vm" ]
then
  ####
  # Network manager
  # P
  ####
  apt-get remove --purge -y network-manager
  if dpkg -l wicd | grep -E "ii\s+wicd"
  then
    apt-get remove --purge -y wicd
  fi

  ####
  # VirtualBox
  # P
  ####
  echo "deb http://download.virtualbox.org/virtualbox/debian stretch contrib" > /etc/apt/sources.list.d/virtualbox.list

  wget --no-check-certificate https://www.virtualbox.org/download/oracle_vbox_2016.asc
  apt-key add oracle_vbox_2016.asc

  apt-get update -y

  # Nécessaire pour installer VirtualBox
  apt-get install -y "linux-headers-$(uname -r)"

  # 734 Mo en plus
  # Trouver automatiquement la dernière version disponible
  v=$(apt-cache search virtualbox- | cut -d' ' -f1 | cut -d'-' -f2 | sort -V | tail -n 1)
  echo "Installation de virtualbox-$v"
  apt-get install -y virtualbox-$v

  ####
  # Packages
  # P
  # TODO : ne pas installer les "utilitaires usuels du système" ?
  # Liste : aptitude search ~pstandard ~prequired ~pimportant -F%p
  # Source https://wiki.debian.org/tasksel#A.22standard.22_task
  ####
  #Firefox, Open Office
  apt-get install -y sudo

  # Anticiper la question de l'installateur
  echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections

  apt-get install -y wireshark
  apt-get install -y openssh-server filezilla
  apt-get install -y evince shutter

  ####
  # Atom
  ####
  wget --no-check-certificate https://atom.io/download/deb -O atom.deb
  apt-get install -y git
  dpkg -i atom.deb

  ####
  # Packer
  # Pas de lien vers la latest version :
  # https://github.com/hashicorp/terraform/issues/9803
  ####
  wget --no-check-certificate https://releases.hashicorp.com/packer/1.2.4/packer_1.2.4_linux_amd64.zip -O packer.zip
  unzip -o -d /usr/local/bin packer.zip
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

if [ "$DEPLOY_TYPE" != "vm" ]
then
  ####
  # Verrouillage numérique en GUI
  ####
  apt-get install -y numlockx

  # Ajout au début du script, après le shebang
  sed -i '2a /usr/bin/numlockx on' /etc/X11/xinit/xinitrc

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
pref("network.proxy.ssl", "$PROXYIUT");
pref("network.proxy.ssl_port", $PROXYIUT_PORT);
pref("network.proxy.ftp", "$PROXYIUT");
pref("network.proxy.ftp_port", $PROXYIUT_PORT);
pref("network.proxy.no_proxies_on", "localhost,127.0.0.1,172.16.0.0/24,*.iutcv.fr");
pref("network.proxy.type", 1);
EOF

  ####
  # Partition DATA
  # P
  ####
  mkdir -p /mnt/DATA

  win=$(fdisk -l | grep Microsoft | cut -d ' ' -f 1)
  part_data=""

  for p in $win
  do
    if blkid $p | grep ntfs > /dev/null 2>&1
    then
      mount $p /mnt/DATA
      if [ ! -d /mnt/DATA/Windows ]
      then
        if [ "$part_data" != "" ]
        then
          echo "Il existe plusieurs partitions de données (NTFS sans OS)."
          echo "Impossible de choisir."
          exit
        fi
        part_data=$p
      fi
      umount /mnt/DATA
    fi
  done

  if [ $part_data != "" ]
  then
    sed -E -i '/\/mnt\/DATA/d' /etc/fstab
    echo "$part_data   /mnt/DATA   ntfs    0    0" >> /etc/fstab

    # Raccourci dans Nautilus
    #sudo -u etudiant bash -c "sed -E -i '/\/mnt\/DATA/d' ~/.config/gtk-3.0/bookmarks"
    sudo -u etudiant bash -c "mkdir -p ~/.config/gtk-3.0/; echo \"file:///mnt/DATA DATA\" >> ~/.config/gtk-3.0/bookmarks"
  else
    echo "Pas de partition de données sur le disque."
  fi

  ####
  # Gnome terminal
  # dconf dump / n'affiche pas toutes les valeurs, slt les valeurs modifiées
  # Identifier une clé : modifier manuellement, puis dconf dump / pour voir les différences
  # https://forums.opensuse.org/showthread.php/513424-how-to-change-gnome-terminal-colors-from-cli
  # https://www.hadji.co/switch-terminal-colors-at-night/
  ####

  # Erreurs mais fonctionne quand même
  # (dconf:548): dconf-CRITICAL **: unable to create directory '/run/user/1000/dconf': Permission non accordée.  dconf will not work properly.
  # Escaper les $ sinon les variables sont substituées trop tôt !
  # https://stackoverflow.com/questions/28793746/setting-variable-in-bash-c
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && p=\$(gsettings get org.gnome.Terminal.ProfilesList default | cut -d \' -f 2) \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/use-theme-colors \"false\" \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/background-color \"'rgb(50,150,50)'\" \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/foreground-color \"'rgb(200,200,100)'\""

  ####
  # Gnome Favoris
  ####
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
