#!/usr/bin/env bash
#
# Restore Docker Compose named volumes from a Borg archive on a remote
# repository, then clone or fast-forward the Compose repository.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/compose-volume-backup.env"
ARCHIVE_NAME=""
LIST_ARCHIVES=false
REPLACE_EXISTING=false
START_PROJECTS=false

usage() {
  cat <<EOF
Usage:
  $0 [--config FILE] --list
  $0 [--config FILE] --archive ARCHIVE [--replace-existing] [--start]

Options:
  --archive ARCHIVE    Restore this archive from the remote Borg repository.
  --config FILE        Configuration file (default: $CONFIG_FILE).
  --list               List remote archives and exit.
  --replace-existing   Delete each existing target volume before restoring it.
  --start              Start discovered Compose projects after restoring volumes.
EOF
}

while (($# > 0)); do
  case "$1" in
    --archive)
      ARCHIVE_NAME="${2:?--archive requires an archive name}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:?--config requires a file path}"
      shift 2
      ;;
    --list)
      LIST_ARCHIVES=true
      shift
      ;;
    --replace-existing)
      REPLACE_EXISTING=true
      shift
      ;;
    --start)
      START_PROJECTS=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$LIST_ARCHIVES" == false && -z "$ARCHIVE_NAME" ]]; then
  printf 'Specify --archive ARCHIVE or --list.\n' >&2
  usage >&2
  exit 1
fi

if [[ "$LIST_ARCHIVES" == true && -n "$ARCHIVE_NAME" ]]; then
  printf '%s\n' '--list and --archive cannot be used together.' >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'Configuration file not found: %s\n' "$CONFIG_FILE" >&2
  exit 1
fi

# The configuration is administrator-controlled and may contain Borg's
# credential environment variables, so it is intentionally sourced.
# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${REMOTE_BORG_REPOSITORY:?Set REMOTE_BORG_REPOSITORY in $CONFIG_FILE}"
VOLUME_EXPORT_IMAGE="${VOLUME_EXPORT_IMAGE:-docker.io/library/alpine:3.21}"
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/compose-volume-restore.lock}"

for command in borg docker find flock git tar; do
  command -v "$command" >/dev/null ||
    { printf 'Required command not found: %s\n' "$command" >&2; exit 1; }
done

if ! borg_version="$(borg --version)" || [[ ! "$borg_version" =~ ^borg[[:space:]]+2\. ]]; then
  printf 'Borg 2 is required (found: %s).\n' "${borg_version:-unavailable}" >&2
  exit 1
fi

for variable in BORG_RSH BORG_KEY_FILE; do
  if [[ -v "$variable" ]]; then
    export "$variable"
  fi
done

if [[ -v REMOTE_BORG_PASSPHRASE ]]; then
  export BORG_PASSPHRASE="$REMOTE_BORG_PASSPHRASE"
elif [[ -v BORG_PASSPHRASE ]]; then
  export BORG_PASSPHRASE
fi

if [[ -v REMOTE_BORG_PASSCOMMAND ]]; then
  export BORG_PASSCOMMAND="$REMOTE_BORG_PASSCOMMAND"
elif [[ -v BORG_PASSCOMMAND ]]; then
  export BORG_PASSCOMMAND
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  printf 'Another compose volume restore is already running.\n' >&2
  exit 1
fi

sync_compose_repository() {
  : "${COMPOSE_REPOSITORY:?Set COMPOSE_REPOSITORY in $CONFIG_FILE}"
  : "${COMPOSE_CHECKOUT:?Set COMPOSE_CHECKOUT in $CONFIG_FILE}"
  COMPOSE_REF="${COMPOSE_REF:-main}"

  if [[ -e "$COMPOSE_CHECKOUT" && ! -d "$COMPOSE_CHECKOUT/.git" ]]; then
    printf 'Compose checkout exists but is not a Git repository: %s\n' \
      "$COMPOSE_CHECKOUT" >&2
    exit 1
  fi

  if [[ ! -e "$COMPOSE_CHECKOUT" ]]; then
    printf 'Cloning Compose repository into %s\n' "$COMPOSE_CHECKOUT"
    mkdir -p -- "$(dirname -- "$COMPOSE_CHECKOUT")"
    git clone --branch "$COMPOSE_REF" --single-branch \
      "$COMPOSE_REPOSITORY" "$COMPOSE_CHECKOUT"
    return
  fi

  if ! git -C "$COMPOSE_CHECKOUT" diff --quiet ||
    ! git -C "$COMPOSE_CHECKOUT" diff --cached --quiet; then
    printf 'Compose checkout has tracked changes; refusing to overwrite it.\n' >&2
    exit 1
  fi

  printf 'Updating Compose repository in %s\n' "$COMPOSE_CHECKOUT"
  git -C "$COMPOSE_CHECKOUT" fetch --prune origin "$COMPOSE_REF"
  git -C "$COMPOSE_CHECKOUT" checkout --detach FETCH_HEAD
}

declare -a restored_volumes=()
staging_dir=""

cleanup() {
  local status=$?

  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi

  exit "$status"
}

extract_archive() {
  staging_dir="$(mktemp -d "${TMPDIR:-/var/tmp}/compose-volume-restore.XXXXXXXX")"
  trap cleanup EXIT

  printf 'Extracting %s from the Storage Box\n' "$ARCHIVE_NAME"
  borg extract --destination "$staging_dir" \
    "$REMOTE_BORG_REPOSITORY::$ARCHIVE_NAME" volumes

  if [[ ! -d "$staging_dir/volumes" ]]; then
    printf 'Archive %s does not contain exported volumes.\n' "$ARCHIVE_NAME" >&2
    exit 1
  fi

  shopt -s nullglob
  restored_volumes=("$staging_dir"/volumes/*.tar)
  shopt -u nullglob
  if ((${#restored_volumes[@]} == 0)); then
    printf 'Archive %s contains no exported volume tarballs.\n' "$ARCHIVE_NAME" >&2
    exit 1
  fi

  local volume_archive
  for volume_archive in "${restored_volumes[@]}"; do
    tar -tf "$volume_archive" >/dev/null
  done
}

ensure_volume_is_safe_to_restore() {
  local volume=$1
  local attached_containers

  attached_containers="$(docker ps -aq --filter "volume=$volume")"
  if [[ -n "$attached_containers" ]]; then
    printf 'Volume %s is attached to container(s): %s\n' \
      "$volume" "$attached_containers" >&2
    printf 'Stop and remove those containers before restoring.\n' >&2
    return 1
  fi

  if docker volume inspect "$volume" >/dev/null 2>&1; then
    if [[ "$REPLACE_EXISTING" == false ]]; then
      printf 'Volume %s already exists; rerun with --replace-existing to replace it.\n' \
        "$volume" >&2
      return 1
    fi
  fi
}

restore_volumes() {
  local volume_archive volume

  for volume_archive in "${restored_volumes[@]}"; do
    volume="$(basename -- "$volume_archive" .tar)"
    ensure_volume_is_safe_to_restore "$volume"
  done

  for volume_archive in "${restored_volumes[@]}"; do
    volume="$(basename -- "$volume_archive" .tar)"
    printf 'Restoring volume %s\n' "$volume"
    if docker volume inspect "$volume" >/dev/null 2>&1; then
      docker volume rm "$volume" >/dev/null
    fi
    docker volume create "$volume" >/dev/null
    docker run --rm --pull=missing --user 0:0 \
      --mount "type=volume,src=$volume,dst=/target" \
      --mount "type=bind,src=$volume_archive,dst=/backup.tar,readonly" \
      "$VOLUME_EXPORT_IMAGE" \
      tar -C /target -xpf /backup.tar
  done
}

start_compose_projects() {
  local project
  declare -A seen_projects=()
  declare -a projects=()

  while IFS= read -r -d '' project; do
    [[ -v "seen_projects[$project]" ]] && continue
    seen_projects["$project"]=1
    projects+=("$project")
  done < <(
    find "$COMPOSE_CHECKOUT" \
      -path "$COMPOSE_CHECKOUT/.git" -prune -o \
      -type f \( -name compose.yaml -o -name compose.yml \
        -o -name docker-compose.yaml -o -name docker-compose.yml \) \
      -printf '%h\0' | sort -z
  )

  for project in "${projects[@]}"; do
    printf 'Starting Compose project in %s\n' "$project"
    (
      cd -- "$project"
      docker compose up -d
    )
  done
}

if [[ "$LIST_ARCHIVES" == true ]]; then
  borg list --short "$REMOTE_BORG_REPOSITORY"
  exit 0
fi

sync_compose_repository
extract_archive
restore_volumes

if [[ "$START_PROJECTS" == true ]]; then
  start_compose_projects
fi

printf 'Restore completed from archive %s\n' "$ARCHIVE_NAME"
