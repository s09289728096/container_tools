#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/tools/bin/container_common.sh"

usage() {
    echo 'Usage:'
    echo '  ./setup.sh build --list'
    echo '    List available recipes; also the default when no recipe is specified.'
    echo
    echo '  ./setup.sh build [--engine docker|podman] RECIPE [BUILD_OPTIONS...]'
    echo '    Build an image using a containerfiles filename or its number in --list.'
    echo '    Pass BUILD_OPTIONS to the engine build command.'
    echo '    Engine: --engine > CONTAINER_ENGINE > saved setting > docker (rootless).'
}

container_parse_engine "$@"
set -- "${CONTAINER_ARGS[@]}"

shopt -s nullglob
recipes=()
for file in "$ROOT"/containerfiles/*; do
    [[ -f $file ]] && recipes+=("${file##*/}")
done
((${#recipes[@]})) || container_error 'No containerfiles found.'

case ${1:-} in
    -h|--help|help) usage; exit 0 ;;
    ''|--list|-l)
        for i in "${!recipes[@]}"; do printf '%2d. %s\n' "$((i + 1))" "${recipes[i]}"; done
        exit 0 ;;
esac

selection=$1
shift
recipe=
for i in "${!recipes[@]}"; do
    if [[ $selection == "${recipes[i]}" || $selection == "$((i + 1))" ]]; then
        recipe=${recipes[i]}
        break
    fi
done
[[ -n $recipe ]] || container_error "Unknown recipe: $selection. Use --list."
container_engine_init
image=${CONTAINER_IMAGE:-$(container_default_image "$recipe")}
printf 'Building %s with %s from %s\n' "$image" "$CONTAINER_ENGINE" "$recipe"
exec "$CONTAINER_ENGINE" build "$@" \
    --build-arg "CONTAINER_TIMEZONE=${CONTAINER_TIMEZONE:-Asia/Taipei}" \
    --label "$CONTAINER_LABEL=true" \
    --file "$ROOT/containerfiles/$recipe" --tag "$image" "$ROOT"
