#!/usr/bin/env bash
# Loaded automatically by the build and container entry points.
export CONTAINER_ENGINE=docker
# Use the system Docker daemon by default. Override this for another daemon.
# Override with CONTAINER_DOCKER_HOST before sourcing this file if necessary.
unset DOCKER_CONTEXT
export DOCKER_HOST="${CONTAINER_DOCKER_HOST:-unix:///var/run/docker.sock}"
export CONTAINER_FAKEHOME="${CONTAINER_FAKEHOME:-$HOME/.local/usr/home}"
export CONTAINER_TIMEZONE="${CONTAINER_TIMEZONE:-Asia/Taipei}"
