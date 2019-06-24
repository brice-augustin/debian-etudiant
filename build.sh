#!/bin/bash

s=http://cdimage.debian.org/cdimage/release/9.9.0/amd64/iso-cd/SHA512SUMS
iso=http://cdimage.debian.org/cdimage/release/9.9.0/amd64/iso-cd/debian-9.9.0-amd64-netinst.iso

# Actuellement, le checksum n'est pas vérifié.
# "iso_checksum": "PUT CHECKSUM HERE"
#    -> OK
# "iso_checksum_url": "PATH TO SHA256SUM local file"
#    -> Packer thoughs an error (can't verify checksum); bug caused by mismatch of ISO file path ?
# "iso_checksum_url": "URL TO SHA256SUM file on Debian's Website"
#    -> Packer fails to download it behind a proxy
#http_proxy=$PROXY curl $s

isofile=$(echo ${iso##*/})

if [ "$1" == "proxy" ]
then
  PROXY=http://proxy.iutcv.fr:3128
  echo "Building image with proxy enabled"
  echo "d-i mirror/http/proxy string $PROXY" >> preseed-TMP.cfg
else
  echo "Building image with proxy disabled"
fi

if [ ! -f $isofile ]
then
  # wget not installed by default on MacOS
  # curl does not follow redirects. Use -L to force that. 
  http_proxy=$PROXY curl -O -L $iso
else
  echo "Using existing ISO file ($isofile)"
fi

cp preseed.cfg preseed-TMP.cfg

packer validate debian.json
packer build debian.json
