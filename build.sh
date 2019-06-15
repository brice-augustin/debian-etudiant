#!/bin/bash

s=http://cdimage.debian.org/cdimage/release/9.9.0/amd64/iso-cd/SHA512SUMS
iso=http://cdimage.debian.org/cdimage/release/9.9.0/amd64/iso-cd/debian-9.9.0-amd64-netinst.iso

PROXY=http://proxy.iutcv.fr:3128

#http_proxy=$PROXY curl $s
#http_proxy=$PROXY curl $iso
# dl checksum et le passer en paramètre du json
# idem iso

cp preseed.cfg preseed-TMP.cfg

if [ "$1" == "proxy" ]
then
  echo "Building image with proxy enabled"
  echo "d-i mirror/http/proxy string $PROXY" >> preseed-TMP.cfg
else
  echo "Building image with proxy disabled"
fi

packer validate debian.json
packer build debian.json
