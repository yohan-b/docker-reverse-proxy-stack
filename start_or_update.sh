#!/bin/bash
for NETWORK in reverse-proxy
do
    sudo docker network inspect ${NETWORK} && continue
    sudo docker network create ${NETWORK}
    sudo docker network inspect ${NETWORK} || \
    { echo "ERROR: could not create network ${NETWORK}, exiting."; exit 1; }
done

test -f ~/openrc.sh || { echo "ERROR: ~/openrc.sh not found, exiting."; exit 1; }
source ~/openrc.sh
INSTANCE=$(~/env_py3/bin/openstack server show -c id --format value $(hostname))
for VOLUME in reverse-proxy_conf reverse-proxy_conf_enabled reverse-proxy_letsencrypt
do
    mkdir -p /mnt/volumes/${VOLUME}
    if ! mountpoint -q /mnt/volumes/${VOLUME}
    then
         VOLUME_ID=$(/home/yohan/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
         test -e /dev/disk/by-id/*${VOLUME_ID:0:20} || nova volume-attach $INSTANCE $VOLUME_ID auto
         sleep 3
         sudo mount /dev/disk/by-id/*${VOLUME_ID:0:20} /mnt/volumes/${VOLUME}
         mountpoint -q /mnt/volumes/${VOLUME} || { echo "ERROR: could not mount /mnt/volumes/${VOLUME}, exiting."; exit 1; }
    fi
done

sudo chown root. crontab
sudo chmod 644 crontab

export OS_REGION_NAME=GRA
test -f ~/duplicity_password.sh || { echo "ERROR: ~/duplicity_password.sh not found, exiting."; exit 1; }
source ~/duplicity_password.sh

sudo docker image inspect duplicity:latest &> /dev/null || { echo "ERROR: duplicity:latest image not found, exiting."; exit 1; }

rm -rf ~/build
mkdir -p ~/build
for name in docker-cron docker-reverse-proxy
do
    sudo -E docker run --rm -e SWIFT_USERNAME=$OS_USERNAME \
                            -e SWIFT_PASSWORD=$OS_PASSWORD \
                            -e SWIFT_AUTHURL=$OS_AUTH_URL \
                            -e SWIFT_AUTHVERSION=$OS_IDENTITY_API_VERSION \
                            -e SWIFT_TENANTNAME=$OS_TENANT_NAME \
                            -e SWIFT_REGIONNAME=$OS_REGION_NAME \
                            -e PASSPHRASE=$PASSPHRASE \
      --name backup-restore -v ~/build:/mnt/build --entrypoint /bin/bash duplicity:latest \
      -c "duplicity restore --name bootstrap --file-to-restore ${name}.tar.gz swift://bootstrap /mnt/build/${name}.tar.gz"
    tar -xzf ~/build/${name}.tar.gz -C ~/build/
done

# --force-recreate is used to recreate container when crontab file has changed
unset VERSION_PROXY VERSION_CRON
DIRECTORY=$(pwd)
cd ~/build/docker-reverse-proxy; export VERSION_PROXY=$(git show-ref --head| head -1 | cut -f 1|cut -c -10); cd $DIRECTORY
cd ~/build/docker-cron; export VERSION_CRON=$(git show-ref --head| head -1 | cut -f 1|cut -c -10); cd $DIRECTORY

sudo docker build -t reverse-proxy:$VERSION_PROXY ~/build/docker-reverse-proxy
sudo docker build -t cron:$VERSION_CRON ~/build/docker-cron

sudo -E bash -c 'docker-compose up -d --force-recreate'

rm -rf ~/build
