#!/bin/bash
# Cron job for Passbolt on Hostinger
export PHP=/opt/cloudlinux/alt-php83/root/usr/bin/php
DIR=$(dirname "$0")
cd "$DIR"
./bin/cron
echo "Executed"
