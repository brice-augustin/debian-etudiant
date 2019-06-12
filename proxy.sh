#!/bin/bash

# https://gist.github.com/nathanchrs/50a8b51fd4d84d92fe07b5dc2881c860

export PROXYIUT="proxy.iutcv.fr"
export PROXYIUT_PORT="3128"

if [ $EUID -ne 0 ]
then
  echo "Doit être exécuté en tant que root"
  exit
fi

if [ $# -lt 1 ]
then
  echo "$0 enable|disable"
  exit
fi

if [ $1 == "enable" ]
then
  if [ "$2" != "force" -a "$http_proxy" != "" ]
  then
    echo "Le proxy est déjà activé."
    exit
  fi

  ####
  # Proxy du navigateur Web
  # P
  ####

  # https://support.mozilla.org/fr/questions/901549
  # network.proxy.share_proxy_settings = true pour configurer le proxy HTTP pour
  # tous les autres protocoles : pas d'effet sur la dialog box
  # Mais sans importance il faut surtout que le proxy SSL/FTP/etc soit bien
  # configuré dans les cases en dessous
  # pref("network.proxy.ssl", "$PROXYIUT");
  # pref("network.proxy.ssl_port", "$PROXYIUT_PORT");
  # pref("network.proxy.ftp", "$PROXYIUT");
  # pref("network.proxy.ftp_port", "$PROXYIUT_PORT");
  if [ -d /usr/lib/firefox-esr/defaults/pref/ ]
  then
    cat > /usr/lib/firefox-esr/defaults/pref/local-settings.js << EOF
pref("network.proxy.http", "$PROXYIUT");
pref("network.proxy.http_port", $PROXYIUT_PORT);
pref("network.proxy.share_proxy_settings", true);
pref("network.proxy.ssl", "$PROXYIUT");
pref("network.proxy.ssl_port", $PROXYIUT_PORT);
pref("network.proxy.ftp", "$PROXYIUT");
pref("network.proxy.ftp_port", $PROXYIUT_PORT);
pref("network.proxy.no_proxies_on", "localhost,127.0.0.1,172.16.0.0/16,*.iutcv.fr");
pref("network.proxy.type", 1);
EOF
  fi

  # Effacer toute config de *_proxy
  sed -E -i '/(ht|f)tps?_proxy=/d' /etc/bash.bashrc

  echo "export http_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc
  echo "export https_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc
  echo "export ftp_proxy=http://$PROXYIUT:$PROXYIUT_PORT" >> /etc/bash.bashrc

  echo "Acquire::http::Proxy \"http://$PROXYIUT:$PROXYIUT_PORT\";" > /etc/apt/apt.conf.d/80proxy

  echo "Acquire::http::Proxy \"http://$PROXYIUT:$PROXYIUT_PORT\";" > /etc/apt/apt.conf

  #reboot
elif [ $1 == "disable" ]
then
  if [ "$2" != "force" -a "$http_proxy" == "" ]
  then
    echo "Le proxy est déjà désactivé."
    exit
  fi

  rm /usr/lib/firefox-esr/defaults/pref/local-settings.js

  # Effacer toute config de *_proxy
  sed -E -i '/(ht|f)tps?_proxy=/d' /etc/bash.bashrc

  sed -E -i '/^Acquire::http::Proxy/d' /etc/apt/apt.conf

  rm /etc/apt/apt.conf.d/80proxy

  #reboot
fi
