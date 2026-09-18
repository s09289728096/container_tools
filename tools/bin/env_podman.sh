#!/usr/bin/env bash
# Loaded automatically by the entry points; Podman uses its local rootless storage.
export CONTAINER_ENGINE=podman
export CONTAINER_FAKEHOME="${CONTAINER_FAKEHOME:-$HOME/.local/usr/home}"
export CONTAINER_TIMEZONE="${CONTAINER_TIMEZONE:-Asia/Taipei}"
