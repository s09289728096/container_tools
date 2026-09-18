#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/container_common.sh"

usage() {
    echo 'Usage:'
    echo "  ${0##*/} [--engine docker|podman] --list"
    echo '    List project images and their recipe labels; also the default when no image is specified.'
    echo
    echo "  ${0##*/} [--engine docker|podman] IMAGE [COMMAND [ARG...]]"
    echo '    Start an container.'
    echo '    IMAGE accepts a full image reference/ID or a recipe name.'
    echo '    CONTAINER_WORKSPACE defaults to the $HOME/workspace, mounted at /workspace.'
}

list_images() {
    local rows repository tag image_id short_id label
    # Docker image listing does not expose labels; inspect works with both engines.
    rows=$("$CONTAINER_ENGINE" images --filter "label=$CONTAINER_LABEL=true" \
        --no-trunc --format '{{.Repository}}\t{{.Tag}}\t{{.ID}}')
    printf '%-48s  %-16s  %-12s  %s\n' 'REPOSITORY' 'TAG' 'IMAGE ID' 'LABEL'
    [[ -n $rows ]] || return 0
    while IFS=$'\t' read -r repository tag image_id; do
        label=$("$CONTAINER_ENGINE" image inspect \
            --format "{{with index .Config.Labels \"$CONTAINER_RECIPE_LABEL\"}}{{.}}{{end}}" "$image_id")
        short_id=${image_id#sha256:}
        printf '%-48s  %-16s  %-12s  %s\n' "$repository" "$tag" "${short_id:0:12}" "$label"
    done <<< "$rows"
}

container_parse_engine "$@"
set -- "${CONTAINER_ARGS[@]}"

case ${1:-} in
    -h|--help|help) usage; exit 0 ;;
    ''|-l|--list)
        container_engine_init
        list_images
        exit 0 ;;
    -*) usage >&2; exit 1 ;;
esac

container_engine_init
image=$1
shift
# Bare recipe names resolve to this user's images; explicit references/IDs stay intact.
if [[ $image != */* && $image != *:* && ! $image =~ ^[a-f0-9]{12,64}$ ]]; then
    image=$(container_default_image "$image")
fi
managed=$("$CONTAINER_ENGINE" image inspect --format "{{index .Config.Labels \"$CONTAINER_LABEL\"}}" "$image") ||
    container_error "Image not found locally: $image. Use --list or setup.sh build."
[[ $managed == true ]] || container_error "Image is not labeled $CONTAINER_LABEL=true: $image"

recipe_label=$("$CONTAINER_ENGINE" image inspect \
    --format "{{with index .Config.Labels \"$CONTAINER_RECIPE_LABEL\"}}{{.}}{{end}}" "$image")
# Descriptive labels may contain spaces or punctuation. Use a DNS-compatible name.
container_hostname=$(printf '%s' "$recipe_label" | tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c 1-63)
container_hostname=${container_hostname%-}
[[ -n $container_hostname ]] ||
    container_error "Image label $CONTAINER_RECIPE_LABEL must contain letters or digits to form a hostname: $image"

fakehome=${CONTAINER_FAKEHOME:-$HOME/.local/usr/home}
workspace=${CONTAINER_WORKSPACE:-$HOME/workspace}
[[ -d $fakehome ]] || container_error "Missing fakehome: $fakehome. Run setup.sh install first."
[[ -d $workspace ]] || container_error "Missing workspace: $workspace"
fakehome=$(cd -- "$fakehome" && pwd -P)
workspace=$(cd -- "$workspace" && pwd -P)
# --mount uses commas as field separators; fail rather than misparse such paths.
[[ $fakehome != *,* && $workspace != *,* ]] || container_error 'Mount paths cannot contain commas.'

# Seed a writable copy on the host. Nested file mounts can leave runtime-owned
# placeholder files inside the bind-mounted home (especially with keep-id).
if [[ -f $HOME/.gitconfig && ! -e $fakehome/.gitconfig && ! -L $fakehome/.gitconfig ]]; then
    (umask 077; cp --no-clobber -- "$HOME/.gitconfig" "$fakehome/.gitconfig")
fi
if [[ -e $fakehome/.gitconfig && (! -r $fakehome/.gitconfig || ! -w $fakehome/.gitconfig) ]]; then
    container_error "Cannot edit $fakehome/.gitconfig. Repair its host ownership before starting the container; see README."
fi

args=(run --rm --pull=never -i)
[[ -t 0 && -t 1 ]] && args+=(-t)
if [[ $CONTAINER_ENGINE == podman ]]; then
    # Initialize /etc/passwd and sudoers as namespace root, then the image
    # entrypoint drops to the host UID/GID before executing the requested command.
    args+=(--userns=keep-id --passwd=false --user 0:0)
    container_uid=$(id -u)
    container_gid=$(id -g)
    container_user=$(id -un)
else
    # Rootless Docker maps container root to the invoking host user.
    args+=(--user 0:0)
    container_uid=0
    container_gid=0
    container_user=root
fi
args+=(--mount "type=bind,src=$fakehome,dst=/home/container"
       --mount "type=bind,src=$workspace,dst=/workspace"
       --workdir /workspace --hostname "$container_hostname"
       --entrypoint /usr/local/bin/container-tools-entrypoint
       --env "CONTAINER_UID=$container_uid" --env "CONTAINER_GID=$container_gid"
       --env "CONTAINER_USER=$container_user"
       --env HOME=/home/container --env "USER=$container_user"
       --env "LOGNAME=$container_user"
       --env "TZ=${CONTAINER_TIMEZONE:-Asia/Taipei}")
[[ -z ${TERM:-} ]] || args+=(--env "TERM=$TERM")
(($#)) || set -- /bin/bash
exec "$CONTAINER_ENGINE" "${args[@]}" "$image" "$@"
