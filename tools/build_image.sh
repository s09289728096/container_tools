#!/bin/bash

if test "$1" = "1";then
	UBUNTU_VERSION=1604
elif test "$1" = "2"; then
	UBUNTU_VERSION=1804
elif test "$1" = "3"; then
	UBUNTU_VERSION=2004
elif test "$1" = "4"; then
	UBUNTU_VERSION=2204
elif test "$1" = "5"; then
	UBUNTU_VERSION=2404
else
	echo "Select the number to build the release version of ubuntu:"
	echo "  1. ubuntu-1604"
	echo "  2. ubuntu-1804"
	echo "  3. ubuntu-2004"
	echo "  4. ubuntu-2204"
	echo "  5. ubuntu-2404"
	exit
fi

echo "build ubuntu-$UBUNTU_VERSION"
DOCKERFILE_NAME=dockerfile_$UBUNTU_VERSION
IMAGE_NAME=ubuntu-$UBUNTU_VERSION
echo "link dockerfile..."
rm dockerfile
ln -s docker_buildfile/$DOCKERFILE_NAME dockerfile
echo "build image..."
docker build . -t $IMAGE_NAME
