#!/usr/bin/env bash
# Shared by build_image.sh and goto_container.sh; not a standalone command.
CONTAINER_LABEL=io.container-tools.managed
CONTAINER_RECIPE_LABEL=io.container-tools.recipe

container_error() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

container_engine_config() {
    printf '%s/container-tools/engine\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

container_default_image() {
    printf '%s/%s:latest\n' "$(id -un)" "$1"
}

# Consume only leading engine options, preserving image command/build arguments.
container_parse_engine() {
    while (($#)); do
        case $1 in
            --engine)
                (($# >= 2)) || container_error '--engine requires docker or podman.'
                export CONTAINER_ENGINE=$2
                shift 2 ;;
            --engine=*) export CONTAINER_ENGINE=${1#*=}; shift ;;
            *) break ;;
        esac
        case $CONTAINER_ENGINE in
            docker|podman) ;;
            *) container_error '--engine must be docker or podman.' ;;
        esac
    done
    CONTAINER_ARGS=("$@")
}

container_engine_init() {
    local config
    config=$(container_engine_config)
    if [[ -z ${CONTAINER_ENGINE:-} && -e $config ]]; then
        CONTAINER_ENGINE=$(cat -- "$config") || container_error "Cannot read engine configuration: $config"
        case $CONTAINER_ENGINE in
            docker|podman) ;;
            *) container_error "Invalid engine configuration: $config. Run setup.sh setengine docker|podman." ;;
        esac
    fi
    CONTAINER_ENGINE=${CONTAINER_ENGINE:-docker}
    case $CONTAINER_ENGINE in
        docker|podman) ;;
        *) container_error 'CONTAINER_ENGINE must be docker or podman.' ;;
    esac
    local env_dir
    env_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    source "$env_dir/env_${CONTAINER_ENGINE}.sh"
    command -v "$CONTAINER_ENGINE" >/dev/null || container_error "$CONTAINER_ENGINE is not installed."
    local info
    if [[ $CONTAINER_ENGINE == podman ]]; then
        info=$(podman info --format '{{.Host.Security.Rootless}}') ||
            container_error 'Cannot access Podman. Check the rootless runtime configuration.'
        [[ $info == true ]] || container_error 'Podman must run rootless, without sudo.'
    else
        docker info >/dev/null 2>&1 ||
            container_error 'Cannot access Docker. Start the system Docker daemon or set CONTAINER_DOCKER_HOST to its socket.'
    fi
}
