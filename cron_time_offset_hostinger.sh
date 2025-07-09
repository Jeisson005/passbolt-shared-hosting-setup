#!/bin/bash
# Time offset script for Passbolt on Hostinger
export PHP=/opt/cloudlinux/alt-php83/root/usr/bin/php
DIR=$(dirname "$0")
cd "$DIR"
$PHP "cron_time_offset.php"
