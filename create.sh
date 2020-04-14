#!/bin/bash
#Absolute path to this script
SCRIPT=$(readlink -f $0)
#Absolute path this script is in
SCRIPTPATH=$(dirname $SCRIPT)

cd $SCRIPTPATH

for NETWORK in reverse-proxy
do
    sudo docker network inspect ${NETWORK} &> /dev/null && continue
    sudo docker network create ${NETWORK}
    sudo docker network inspect ${NETWORK} &> /dev/null || \
    { echo "ERROR: could not create network ${NETWORK}, exiting."; exit 1; }
done

if test -z "$1" || [ "$1" != "local" ]
then
    test -f ~/openrc.sh || { echo "ERROR: ~/openrc.sh not found, exiting."; exit 1; }
    source ~/openrc.sh
    export OS_REGION_NAME=GRA
    test -f ~/duplicity_password.sh || { echo "ERROR: ~/duplicity_password.sh not found, exiting."; exit 1; }
    source ~/duplicity_password.sh
    
    sudo docker image inspect duplicity:latest &> /dev/null || { echo "ERROR: duplicity:latest image not found, exiting."; exit 1; }
    
    rm -rf ~/build
    mkdir -p ~/build
    for name in docker-reverse-proxy
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
    unset VERSION_PROXY
    cd ~/build/docker-reverse-proxy; export VERSION_PROXY=$(git show-ref --head| head -1 | cut -f 1|cut -c -10)
    cd $SCRIPTPATH
else
    unset VERSION_PROXY
    export VERSION_PROXY=$(git ls-remote https://git.scimetis.net/yohan/docker-reverse-proxy.git| head -1 | cut -f 1|cut -c -10)
    rm -rf ~/build
    mkdir -p ~/build
    git clone https://git.scimetis.net/yohan/docker-reverse-proxy.git ~/build/docker-reverse-proxy
fi
sudo docker build -t reverse-proxy:$VERSION_PROXY ~/build/docker-reverse-proxy

sudo -E bash -c 'docker-compose up --no-start --force-recreate'

rm -rf ~/build
