#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$ROOT/tools/bin/container_common.sh"
BIN_DIR=$HOME/.local/bin
FAKEHOME=$HOME/.local/usr/home
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/container-tools/installed
TEMP_FILE=
trap '[[ -z $TEMP_FILE ]] || rm -f -- "$TEMP_FILE"' EXIT

usage() {
    echo 'Usage:'
    echo "  $0 install"
    echo '    Copy project scripts to ~/.local/bin and seed ~/.local/usr/home.'
    echo
    echo "  $0 uninstall"
    echo '    Remove unmodified installed scripts; keep fakehome and the engine setting.'
    echo
    echo "  $0 setengine docker|podman"
    echo '    Save the default engine for both build and run environment'
    echo
    echo "  $0 build [--engine docker|podman] [--list | RECIPE [BUILD_OPTIONS...]] {target image}"
    echo '    List available recipes or build an image; --engine overrides the engine for this build.'
}

case ${1:-} in
    build) shift; exec "$ROOT/tools/build_image.sh" "$@" ;;
    setengine)
        [[ $# == 2 ]] || { usage >&2; exit 1; }
        case $2 in
            docker|podman) ;;
            *) container_error 'setengine requires docker or podman.' ;;
        esac
        config=$(container_engine_config)
        mkdir -p -- "${config%/*}"
        TEMP_FILE=$(mktemp "${config}.XXXXXX")
        printf '%s\n' "$2" > "$TEMP_FILE"
        mv -fT -- "$TEMP_FILE" "$config"
        TEMP_FILE=
        printf 'Default engine: %s\nSaved to: %s\n' "$2" "$config"
        exit 0 ;;
    install|uninstall) action=$1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac
[[ $# == 1 ]] || { usage >&2; exit 1; }

file_digest() {
    # Hash stdin so filenames (including spaces) never enter the checksum output.
    local digest
    digest=$(sha256sum < "$1") || return
    printf '%s\n' "${digest%% *}"
}

is_managed_copy() {
    local target=$1 record=$STATE_DIR/${1##*/}
    [[ -f $target && ! -L $target && -f $record ]] &&
        [[ $(file_digest "$target") == "$(cat -- "$record")" ]]
}

is_legacy_link() {
    [[ -L $1 && $(readlink -- "$1") == "$ROOT/tools/bin/${1##*/}" ]]
}

if [[ $action == install ]]; then
    # Preflight all names before replacing any installed script.
    for source in "$ROOT"/tools/bin/*.sh; do
        target=$BIN_DIR/${source##*/}
        if [[ -e $target || -L $target ]]; then
            if ! is_managed_copy "$target" && ! is_legacy_link "$target"; then
                container_error "Refusing to replace unrelated or modified file: $target"
            fi
        fi
    done
    mkdir -p -- "$BIN_DIR" "$FAKEHOME" "$STATE_DIR"
    for source in "$ROOT"/tools/bin/*.sh; do
        target=$BIN_DIR/${source##*/}
        TEMP_FILE=$(mktemp "$BIN_DIR/.container-tools.XXXXXX")
        install -m 755 -- "$source" "$TEMP_FILE"
        # Rename replaces old symlinks instead of following them into the checkout.
        mv -fT -- "$TEMP_FILE" "$target"
        TEMP_FILE=$(mktemp "$STATE_DIR/.record.XXXXXX")
        file_digest "$target" > "$TEMP_FILE"
        mv -fT -- "$TEMP_FILE" "$STATE_DIR/${source##*/}"
        TEMP_FILE=
    done
    # Preserve existing dotfiles and all data stored in the container home.
    for source in "$ROOT"/fakehome/.[!.]* "$ROOT"/fakehome/*; do
        [[ -f $source ]] || continue
        target=$FAKEHOME/${source##*/}
        [[ -e $target || -L $target ]] || cp -- "$source" "$target"
    done
    printf 'Installed scripts: %s\nContainer home: %s\n' "$BIN_DIR" "$FAKEHOME"
    case :$PATH: in
        *:"$BIN_DIR":*) ;;
        *) echo 'Add to your shell configuration: export PATH="$HOME/.local/bin:$PATH"' ;;
    esac
    echo ''
    echo 'Run: goto_container.sh --list'
else
    # Include recorded names even if a future checkout no longer ships them.
    shopt -s nullglob
    for record in "$STATE_DIR"/*.sh; do
        target=$BIN_DIR/${record##*/}
        if is_managed_copy "$target"; then
            rm -- "$target" "$record"
            printf 'Removed %s\n' "$target"
        elif [[ ! -e $target && ! -L $target ]]; then
            rm -- "$record"
        else
            printf 'Preserved modified or replaced file: %s\n' "$target"
        fi
    done
    for source in "$ROOT"/tools/bin/*.sh; do
        target=$BIN_DIR/${source##*/}
        if is_legacy_link "$target"; then
            rm -- "$target"
            printf 'Removed %s\n' "$target"
        fi
    done
    printf 'Preserved container home: %s\n' "$FAKEHOME"
    printf 'Preserved engine setting: %s\n' "$(container_engine_config)"
fi
