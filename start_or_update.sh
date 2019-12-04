#!/bin/bash
sudo chown root. crontab
sudo chmod 644 crontab
# --force-recreate is used to recreate container when crontab file has changed
unset VERSION_PROXY VERSION_CRON
VERSION_PROXY=$(git ls-remote https://git.scimetis.net/yohan/docker-reverse-proxy.git| head -1 | cut -f 1|cut -c -10) \
VERSION_CRON=$(git ls-remote https://git.scimetis.net/yohan/docker-cron.git| head -1 | cut -f 1|cut -c -10) \
 sudo -E bash -c 'docker-compose up -d --force-recreate'

