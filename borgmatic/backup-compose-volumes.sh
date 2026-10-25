#!/usr/bin/env bash
#
# Back up Docker Compose named volumes to a local Borg repository, then copy
# the newly-created archive to a remote Borg repository.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="$SCRIPT_DIR/compose-volume-backup.env"
CONFIG_FILE="${1:-$DEFAULT_CONFIG}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'Configuration file not found: %s\n' "$CONFIG_FILE" >&2
  printf 'Copy %s.example to %s and set its values.\n' \
    "$DEFAULT_CONFIG" "$DEFAULT_CONFIG" >&2
  exit 1
fi

# The configuration is administrator-controlled and may contain Borg's
# credential environment variables, so it is intentionally sourced.
# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${LOCAL_BORG_REPOSITORY:?Set LOCAL_BORG_REPOSITORY in $CONFIG_FILE}"
: "${REMOTE_BORG_REPOSITORY:?Set REMOTE_BORG_REPOSITORY in $CONFIG_FILE}"

SOURCE_ROOT="${BACKUP_SOURCE_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
VOLUME_EXPORT_IMAGE="${VOLUME_EXPORT_IMAGE:-docker.io/library/alpine:3.21}"
LOCK_FILE="${LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/compose-volume-backup.lock}"

for command in borg docker find flock tar; do
  command -v "$command" >/dev/null ||
    { printf 'Required command not found: %s\n' "$command" >&2; exit 1; }
done

if ! borg_version="$(borg --version)" || [[ ! "$borg_version" =~ ^borg[[:space:]]+2\. ]]; then
  printf 'Borg 2 is required for "borg transfer" (found: %s).\n' \
    "${borg_version:-unavailable}" >&2
  exit 1
fi

for variable in BORG_RSH BORG_PASSPHRASE BORG_PASSCOMMAND BORG_KEY_FILE \
  BORG_OTHER_REPO_PASSPHRASE; do
  if [[ -v "$variable" ]]; then
    export "$variable"
  fi
done

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  printf 'Another compose volume backup is already running.\n' >&2
  exit 1
fi

declare -a projects=()
declare -a started_projects=()
declare -A project_services=()
declare -A volumes=()
staging_dir=""
services_restored=false

cleanup() {
  local status=$?

  if [[ "$services_restored" == false ]]; then
    restore_services || status=1
  fi

  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi

  exit "$status"
}

restore_services() {
  local project

  for project in "${started_projects[@]}"; do
    read -r -a services <<<"${project_services[$project]}"
    printf 'Restarting services in %s\n' "$project"
    (
      cd -- "$project"
      docker compose up -d "${services[@]}"
    )
  done

  services_restored=true
}

discover_projects() {
  local compose_file project
  declare -A seen_projects=()

  while IFS= read -r -d '' compose_file; do
    project="$compose_file"
    [[ -v "seen_projects[$project]" ]] && continue
    seen_projects["$project"]=1
    projects+=("$project")
  done < <(
    find "$SOURCE_ROOT" \
      -path "$SOURCE_ROOT/.git" -prune -o \
      -type f \( -name compose.yaml -o -name compose.yml \
        -o -name docker-compose.yaml -o -name docker-compose.yml \) \
      -printf '%h\0' | sort -z
  )

  if ((${#projects[@]} == 0)); then
    printf 'No Compose projects found below %s\n' "$SOURCE_ROOT" >&2
    exit 1
  fi
}

collect_project_state() {
  local project container volume service
  local -a containers=()
  local -a services=()

  for project in "${projects[@]}"; do
    mapfile -t containers < <(
      cd -- "$project"
      docker compose ps -aq
    )

    for container in "${containers[@]}"; do
      while IFS= read -r volume; do
        [[ -n "$volume" ]] && volumes["$volume"]=1
      done < <(
        docker inspect --format \
          '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' \
          "$container"
      )
    done

    mapfile -t services < <(
      cd -- "$project"
      docker compose ps --status running --services
    )

    if ((${#services[@]} > 0)); then
      project_services["$project"]="${services[*]}"
      started_projects+=("$project")
    fi
  done

  if ((${#volumes[@]} == 0)); then
    printf 'No named volumes attached to Compose project containers were found.\n' >&2
    exit 1
  fi
}

stop_services() {
  local project

  for project in "${started_projects[@]}"; do
    printf 'Stopping Compose project in %s\n' "$project"
    (
      cd -- "$project"
      docker compose down
    )
  done
}

export_volumes() {
  local volume archive_name
  local -a sorted_volumes=()

  mapfile -t sorted_volumes < <(printf '%s\n' "${!volumes[@]}" | sort)

  mkdir -p -- "$staging_dir/volumes"
  for volume in "${sorted_volumes[@]}"; do
    archive_name="$staging_dir/volumes/$volume.tar"
    printf 'Exporting volume %s\n' "$volume"
    docker run --rm --pull=missing --user 0:0 \
      --mount "type=volume,src=$volume,dst=/source,readonly" \
      "$VOLUME_EXPORT_IMAGE" \
      tar -C /source -cpf - . >"$archive_name"
  done
}

discover_projects
collect_project_state

staging_dir="$(mktemp -d "${TMPDIR:-/var/tmp}/compose-volume-backup.XXXXXXXX")"
trap cleanup EXIT

stop_services
export_volumes

archive_name="compose-volumes-$(hostname -s)-$(date -u +%Y%m%dT%H%M%SZ)"
printf 'Creating local Borg archive %s\n' "$archive_name"
(
  cd -- "$staging_dir"
  borg create --stats --compression zstd,6 \
    "$LOCAL_BORG_REPOSITORY::$archive_name" volumes
)

restore_services

printf 'Transferring %s to the remote Borg repository\n' "$archive_name"
borg transfer --other-repo "$REMOTE_BORG_REPOSITORY" \
  --match-archives "sh:$archive_name" "$LOCAL_BORG_REPOSITORY"

printf 'Backup and transfer completed: %s\n' "$archive_name"
