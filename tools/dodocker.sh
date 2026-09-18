#!/bin/bash

# defualt imahe
IMG='ubuntu-1604'
if [ ! -z $1 ]; then IMG=$1; fi
IMG=$1

[ -z $1 ] && {
	echo -e "Execute Docker image"
	echo -e "\n    syntax: $(basename $0) <image>"
	echo -e "\n    images:"
	echo -e "\t\tub1604"
	echo -e "\t\tub1804"
	echo -e "\t\tub2004"
	echo -e "\t\tub2204"
	echo -e ""
	exit
};

mkdir -p /tmp/${USER}

docker run -it --rm \
--volume="/etc/group:/etc/group:ro" \
--volume="/etc/passwd:/etc/passwd:ro" \
--volume="/etc/shadow:/etc/shadow:ro" \
--volume="/usr/local/etc/sudoers:/etc/sudoers:ro" \
--volume="/usr/local/etc/.vimrc:${HOME}/.vimrc:ro" \
--volume="/usr/local/etc/.bashrc:${HOME}/.bashrc:ro" \
--mount type=bind,source=${HOME}/.gitconfig,destination=${HOME}/.gitconfig \
--mount type=bind,source=/opt,destination=/opt \
--mount type=bind,source=/mnt/ssd_1ta,destination=/mnt/ssd_1ta \
--mount type=bind,source=/mnt/ssd_2td,destination=/mnt/ssd_2td \
--mount type=bind,source=/tmp/${USER},destination=${HOME} \
--mount type=bind,source=${HOME}/workspace,destination=${HOME}/workspace \
--user $(id -u):$(id -g) --hostname $IMG \
--env USER=${USER} \
--env TZ=Asia/Taipei \
-w $(pwd) \
$IMG

#--mount type=bind,source=${HOME}/.gitconfig,destination=${HOME}/.gitconfig \
#--volume="${HOME}/.gitconfig:${HOME}/.gitconfig" \
#--env LC_ALL=en_US.UTF-8 \
#--env LANG=en_US.UTF-8 \
#--env LANGUAGE=en_US.UTF-8 \
