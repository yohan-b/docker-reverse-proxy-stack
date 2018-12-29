#!/bin/bash

unset VERSION; VERSION=$(git ls-remote ssh://git@git.scimetis.net:2222/yohan/docker-reverse-proxy.git| head -1 | cut -f 1|cut -c -10) sudo -E bash -c 'docker-compose up -d'

