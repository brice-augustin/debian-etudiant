#!/bin/bash

if [ $# -ne 1 -o $EUID -ne 0 ]
then
  echo "$0 nouveau-nom (en root)"
  exit
fi

name=$1

hostnamectl set-hostname $name

sed -i "s/^127.0.1.1\s.*$/127.0.1.1    $name    $name.iutcv.fr/" /etc/hosts
