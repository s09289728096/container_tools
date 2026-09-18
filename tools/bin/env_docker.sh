#!/usr/bin/env bash
# Loaded automatically by the build and container entry points.
export CONTAINER_ENGINE=docker
# Set a Docker-specific endpoint so a Podman compatibility socket is not reused.
# Override with CONTAINER_DOCKER_HOST before sourcing this file if necessary.
unset DOCKER_CONTEXT
export DOCKER_HOST="${CONTAINER_DOCKER_HOST:-unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock}"
export CONTAINER_FAKEHOME="${CONTAINER_FAKEHOME:-$HOME/.local/usr/home}"
export CONTAINER_TIMEZONE="${CONTAINER_TIMEZONE:-Asia/Taipei}"
