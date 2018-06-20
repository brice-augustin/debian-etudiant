#!/bin/bash

sleep 5

echo vitrygtr | sudo -S apt-get update

apt-get install -y dnsutils
