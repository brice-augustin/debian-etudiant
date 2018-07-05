#!/bin/bash

if [ -f /tainted ]
then
  color="rgb(20,20,20)"
else
  touch /tainted
  color="rgb(200,200,200)"
fi

sudo -u etudiant bash -c "export \$(dbus-launch) && gsettings set org.gnome.desktop.background primary-color \"$color\""
