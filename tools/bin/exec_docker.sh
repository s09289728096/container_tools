#!/bin/bash

DOCKER_RUN="docker run -it --rm \
	  --mount type=bind,src=/etc/group,dst=/etc/group,readonly \
	  --mount type=bind,src=/etc/passwd,dst=/etc/passwd,readonly \
	  --mount type=bind,src=/etc/shadow,dst=/etc/shadow,readonly \
	  --mount type=bind,src=/usr/src,dst=/usr/src,readonly \
      --mount type=bind,src=/usr/local/etc/sudoers,dst=/etc/sudoers,readonly \
	  --mount type=bind,src=/opt,dst=/opt \
	  --mount type=bind,src=/lib/modules,dst=/lib/modules \
	  --mount type=bind,src=${HOME}/workspace,dst=${HOME}/workspace \
	  --user $(id -u):$(id -g) --ulimit stack=-1:-1 --ulimit core=-1:-1 \
	  --mount type=bind,src=${HOME}/docker_home,dst=${HOME} \
	  --env USER=${whoami} --env TZ=Asia/Taipei \
	  -w ${HOME} --hostname $1"

if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    docker images
    exit
fi
if [ -z "$1" ]; then
    echo "syntax: "
    echo "$0 <docker_image>"
    echo ""
    echo "Support images:"
    echo "      ubuntu-1604"
    echo "      ubuntu-1804"
    echo "      ubuntu-2004"
    echo "      ubuntu-2204"
    echo "      ubuntu-2404"
    echo ""
    echo "\"--help\" for more image information"
	exit
fi

mkdir -p /tmp/$(whoami)

echo "Using image $1"
$DOCKER_RUN $1

