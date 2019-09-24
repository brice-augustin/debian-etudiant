#!/bin/bash

if [ $EUID -ne 0 ]
then
  echo "Doit être exécuté en tant que root"
  exit
fi

LOGFILE=.debian-etudiant.log

rm $LOGFILE &> /dev/null

# Pour une installation 'light' (PC portables) :
# export DEPLOY_TYPE="light" avant de lancer l'install de RH
if [ "$DEPLOY_TYPE" == "" ]
then
  DEPLOY_TYPE="gui"
fi

####
# Déterminer si on doit utiliser le proxy ou pas
# Truc utilisé : si l'install a été faite avec le proxy, celui-ci
# est configuré dans APT
####
# apt.conf n'existe pas si le proxy n'est pas configuré à l'install
p=$(grep "^Acquire::http::Proxy" /etc/apt/apt.conf 2> /dev/null | cut -d'"' -f 2)

if [ "$p" != "" ]
then
  tmp=${p%:*}
  export PROXYIUT=${tmp#http://}

  export PROXYIUT_PORT=${p##*:}

  # Configurer temporairement le proxy (pour les curl, wget, etc. du script)
  export http_proxy="http://$PROXYIUT:$PROXYIUT_PORT"
  export https_proxy="http://$PROXYIUT:$PROXYIUT_PORT"
  export ftp_proxy="http://$PROXYIUT:$PROXYIUT_PORT"
fi

# TODO : utiliser facter pour savoir si on est sur une VM ou un PC physique

if [ "$DEPLOY_TYPE" == "cli" ]
then
  # Installation in a VM with Packer; pause a few moment
  sleep 5
fi

apt-get update -y >> $LOGFILE 2>&1

# En CLI, NetworkManager n'est pas installé
if [ "$DEPLOY_TYPE" != "cli" ]
then
  ####
  # Network manager
  # light+gui
  ####
  apt-get remove --purge -y network-manager >> $LOGFILE 2>&1
  if dpkg -l wicd | grep -E "ii\s+wicd"
  then
    apt-get remove --purge -y wicd >> $LOGFILE 2>&1
  fi
fi

# Installer certaines apps uniquement sur des PC puissants (pas sur des laptops)
if [ "$DEPLOY_TYPE" == "gui" ]
then
  ####
  # Atom
  # gui
  ####
  wget --no-check-certificate https://atom.io/download/deb -O atom.deb
  apt-get install -y git >> $LOGFILE 2>&1
  dpkg -i atom.deb >> $LOGFILE 2>&1

  ####
  # VirtualBox
  # gui
  ####
  echo "deb http://download.virtualbox.org/virtualbox/debian stretch contrib" > /etc/apt/sources.list.d/virtualbox.list

  wget --no-check-certificate https://www.virtualbox.org/download/oracle_vbox_2016.asc
  apt-key add oracle_vbox_2016.asc

  apt-get update -y >> $LOGFILE 2>&1

  # Nécessaire pour installer VirtualBox
  apt-get install -y "linux-headers-$(uname -r)" >> $LOGFILE 2>&1

  # 734 Mo en plus
  # Trouver automatiquement la dernière version disponible
  v=$(apt-cache search virtualbox- | cut -d' ' -f1 | cut -d'-' -f2 | sort -V | tail -n 1)
  echo "Installation de virtualbox-$v"
  apt-get install -y virtualbox-$v >> $LOGFILE 2>&1

  # Créer vboxnet0; activer DHCP (pas dispo par défaut)
  # Charger les modules nécessaires
  modprobe vboxdrv
  modprobe vboxnetflt
  modprobe vboxnetadp

  sudo -u etudiant bash -c "vboxmanage hostonlyif remove vboxnet0; \
    vboxmanage dhcpserver remove --ifname vboxnet0; \
    vboxmanage hostonlyif create; \
    vboxmanage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1; \
    vboxmanage dhcpserver add --ifname vboxnet0 --ip 192.168.56.2 --netmask 255.255.255.0 --lowerip 192.168.56.3 --upperip 192.168.56.254; \
    vboxmanage dhcpserver modify --ifname vboxnet0 --enable" >> $LOGFILE 2>&1

  # Installer le pack d'extension VirtualBox
  # XXX Trouver l'URL automatiquement
  # Ne pas renommer le fichier downloadé !
  wget https://download.virtualbox.org/virtualbox/6.0.4/Oracle_VM_VirtualBox_Extension_Pack-6.0.4.vbox-extpack
  VBoxManage extpack install --replace Oracle_VM_VirtualBox_Extension_Pack-6.0.4.vbox-extpack <<< "y"
  VBoxManage extpack cleanup
  rm Oracle_VM_VirtualBox_Extension_Pack-6.0.4.vbox-extpack

  ####
  # Dynamips et Dynagen
  # gui
  ####
  sed -i '/^deb .* stretch /s/main$/main contrib non-free/' /etc/apt/sources.list

  apt-get update -y >> $LOGFILE 2>&1
  apt-get install -y dynamips dynagen >> $LOGFILE 2>&1

  sed -i '/^deb .* stretch /s/ contrib non-free//' /etc/apt/sources.list

  apt-get update -y >> $LOGFILE 2>&1

  ####
  # Packer
  # gui
  # Pas de lien vers la latest version :
  # https://github.com/hashicorp/terraform/issues/9803
  ####
  wget --no-check-certificate https://releases.hashicorp.com/packer/1.2.4/packer_1.2.4_linux_amd64.zip -O packer.zip
  unzip -o -d /usr/local/bin packer.zip
fi

# Dans le cas d'une VM créé par Packer, sudo est déjà installé via preseed. Pas grave
apt-get install -y sudo >> $LOGFILE 2>&1

# Ces paquetages n'ont pas d'utilité en CLI
if [ "$DEPLOY_TYPE" != "cli" ]
then
  ####
  # Packages
  # light+gui
  # TODO : ne pas installer les "utilitaires usuels du système" ?
  # Liste : aptitude search ~pstandard ~prequired ~pimportant -F%p
  # Source https://wiki.debian.org/tasksel#A.22standard.22_task
  ####

  # TODO : Firefox, Open Office

  # https://unix.stackexchange.com/questions/367866/how-to-choose-a-response-for-interactive-prompt-during-installation-from-a-shell
  DEBIAN_FRONTEND=noninteractive apt-get -y install wireshark >> $LOGFILE 2>&1
  # Anticiper la question de l'installateur
  echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure wireshark-common >> $LOGFILE 2>&1
  # Autoriser etudiant à capturer le trafic
  usermod -a -G wireshark etudiant

  apt-get install -y openssh-server filezilla >> $LOGFILE 2>&1
  apt-get install -y minicom >> $LOGFILE 2>&1
  apt-get install -y evince >> $LOGFILE 2>&1
  # Utiliser plutôt "Capture d'écran" ?
  apt-get install -y shutter >> $LOGFILE 2>&1
  # Pour José
  apt-get install -y leafpad >> $LOGFILE 2>&1

  apt-get install -y putty >> $LOGFILE 2>&1

  apt-get install -y beep >> $LOGFILE 2>&1
fi

####
# Packages
# cli+light+gui
####
apt-get install -y tcpdump >> $LOGFILE 2>&1
apt-get install -y net-tools iperf iptraf bridge-utils >> $LOGFILE 2>&1
apt-get install -y netcat >> $LOGFILE 2>&1
apt-get install -y exfat-fuse >> $LOGFILE 2>&1
apt-get install -y ethtool >> $LOGFILE 2>&1
apt-get install -y psmisc >> $LOGFILE 2>&1
apt-get install -y man >> $LOGFILE 2>&1
apt-get install -y curl >> $LOGFILE 2>&1

####
# Configuration de sudo
# cli+light+gui
####
adduser etudiant sudo
# etudiant peut faire sudo sans mot de passe
echo "etudiant     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# sudo préserve les variables *_proxy
echo 'Defaults env_keep += "http_proxy https_proxy ftp_proxy"' >> /etc/sudoers

####
# Verrouillage numérique en GUI
# light+gui
####
if [ "$DEPLOY_TYPE" != "cli" ]
then
  apt-get install -y numlockx >> $LOGFILE 2>&1

  # Ajout au début du script, après le shebang
  sed -i '2a /usr/bin/numlockx on' /etc/X11/xinit/xinitrc

  ####
  # Indicateur de restauration
  ####
  cp prep/taint.sh /usr/local/bin

  cat > /etc/systemd/system/taint.service << EOF
[Unit]
Description=Fond d'écran comme indicateur de restauration

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/usr/local/bin/taint.sh

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable taint.service

  # Ne pas supprimer tainted (= laisser l'OS marqué comme 'sali')
  # Il sera marqué comme propre après la restauration
  #[ -f /tainted ] && rm /tainted
  touch tainted
  touch /taint/tainted
  #[ -f /taint/tainted ] && rm /taint/tainted
fi

####
# Partition DATA
# gui
####
if [ "$DEPLOY_TYPE" == "gui" ]
then
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

  if [ "$part_data" != "" ]
  then
    sed -E -i '/\/mnt\/DATA/d' /etc/fstab
    echo "$part_data   /mnt/DATA   ntfs  ro   0    0" >> /etc/fstab

    # Raccourci dans Nautilus
    # Effacer la ligne, si elle existe
    sudo -u etudiant bash -c "sed -E -i '/\/mnt\/DATA/d' ~/.config/gtk-3.0/bookmarks"
    # Ajouter le raccourci
    sudo -u etudiant bash -c "mkdir -p ~/.config/gtk-3.0/; echo \"file:///mnt/DATA DATA\" >> ~/.config/gtk-3.0/bookmarks"
  else
    echo "Pas de partition de données sur le disque."
  fi
fi

####
# Gnome terminal
# gui (pas light ?)
# dconf dump / n'affiche pas toutes les valeurs, slt les valeurs modifiées
# Identifier une clé : modifier manuellement, puis dconf dump / pour voir les différences
# https://forums.opensuse.org/showthread.php/513424-how-to-change-gnome-terminal-colors-from-cli
# https://www.hadji.co/switch-terminal-colors-at-night/
####
if [ "$DEPLOY_TYPE" == "gui" ]
then
  # Erreurs mais fonctionne quand même
  # (dconf:548): dconf-CRITICAL **: unable to create directory '/run/user/1000/dconf': Permission non accordée.  dconf will not work properly.
  # Escaper les $ sinon les variables sont substituées trop tôt !
  # https://stackoverflow.com/questions/28793746/setting-variable-in-bash-c
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && p=\$(gsettings get org.gnome.Terminal.ProfilesList default | cut -d \' -f 2) \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/use-theme-colors \"false\" \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/background-color \"'rgb(50,50,50)'\" \
        && dconf write /org/gnome/terminal/legacy/profiles:/:\$p/foreground-color \"'rgb(200,200,100)'\""

  ####
  # Gnome Favoris
  # /usr/share/applications/
  ####
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && dconf write /org/gnome/shell/favorite-apps \
            \"['firefox-esr.desktop', 'libreoffice-writer.desktop', \
            'org.gnome.Nautilus.desktop', 'virtualbox.desktop', \
            'atom.desktop', 'org.gnome.Terminal.desktop', \
            'wireshark.desktop']\""

  ####
  # Gnome fond d'écran
  ####
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && gsettings set org.gnome.desktop.background picture-uri \"\" \
        && gsettings set org.gnome.desktop.background primary-color \"'rgb(200,200,200)'\""

  ####
  # Désactiver les mises à jour dans Gnome
  ####
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && dconf write /org/gnome/software/download-updates false"

  ####
  # Ecran noir après 15 minutes
  ####
  sudo -u etudiant bash -c "export \$(dbus-launch) \
        && gsettings set org.gnome.desktop.session idle-delay 900"
fi

####
# SSH
# cli+light+gui
####
# Désactiver la connexion SSH avec le login root
# (activé pour provisionner une VM packer)
# 13/06/2019 : autoriser le login root pour simplifier le provisionnement
# avec Packer (pas besoin de sudo, et on peut utiliser le provisionner 'script')
#sed -i '/^PermitRootLogin/s/^/#/' /etc/ssh/sshd_config

####
# Préparation au clonage ou à l'exportation OVA
# cli+light+gui
####
pushd prep
./masterprep.sh
popd

# TODO : Effacer /var/cache/apt/archives
apt autoremove -y >> $LOGFILE 2>&1

# TODO : Timeout /etc/dhcp/dhclient.conf ?
