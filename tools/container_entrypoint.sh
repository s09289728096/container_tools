#!/usr/bin/env bash
# Runs as namespace root, initializes the development account, then drops privileges.
set -euo pipefail

fail() { printf 'Container initialization: %s\n' "$*" >&2; exit 1; }
[[ $(id -u) == 0 ]] || fail 'Start through goto_container.sh so account initialization runs as container root.'
uid=${CONTAINER_UID:-0}
gid=${CONTAINER_GID:-0}
[[ $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] || fail 'CONTAINER_UID/GID must be numeric.'
command -v sudo >/dev/null || fail 'sudo is missing; rebuild this image with setup.sh build.'
home=${CONTAINER_HOME:-/home/${CONTAINER_USER:-container-$uid}}
[[ $home == /home/* ]] || fail 'CONTAINER_HOME must be under /home.'
export HOME=$home SHELL=/bin/bash

if [[ $uid == 0 ]]; then
    # Rootful Docker keeps the initialization process as container root.
    export USER=root LOGNAME=root
else
    group_entry=$(getent group "$gid" || true)
    if [[ -z $group_entry ]]; then
        group_name=container-$gid
        getent group "$group_name" >/dev/null && fail "Group name already exists: $group_name"
        groupadd --gid "$gid" "$group_name"
    fi
    passwd_entry=$(getent passwd "$uid" || true)
    if [[ -n $passwd_entry ]]; then
        existing_account=${passwd_entry%%:*}
        account=${CONTAINER_USER:-$existing_account}
        [[ $account =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || account=$existing_account
        if [[ $account != "$existing_account" ]]; then
            getent passwd "$account" >/dev/null &&
                fail "Account name already exists: $account"
            usermod --login "$account" "$existing_account"
        fi
        # Do not move or chown the bind-mounted home.
        usermod --gid "$gid" --home "$HOME" --shell /bin/bash "$account"
    else
        account=${CONTAINER_USER:-container-$uid}
        [[ $account =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || account=container-$uid
        if getent passwd "$account" >/dev/null; then account=container-$uid; fi
        getent passwd "$account" >/dev/null && fail "Account name already exists: $account"
        useradd --uid "$uid" --gid "$gid" --home-dir "$HOME" --shell /bin/bash \
            --no-create-home --no-log-init "$account"
    fi
    install -d -m 755 /etc/sudoers.d
    printf '#%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$uid" > /etc/sudoers.d/container-tools
    chmod 440 /etc/sudoers.d/container-tools
    visudo -cf /etc/sudoers.d/container-tools >/dev/null
    export USER=$account LOGNAME=$account
fi

(($#)) || set -- /bin/bash
if [[ $uid == 0 ]]; then
    exec "$@"
else
    exec setpriv --reuid "$uid" --regid "$gid" --init-groups -- "$@"
fi
