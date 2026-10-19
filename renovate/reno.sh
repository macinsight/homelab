#!/usr/bin/env bash

set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

gh repo list macinsight-docker --limit 1000 \
  --json nameWithOwner,isArchived \
  --jq '.[] | select(.isArchived | not) | .nameWithOwner' |
while IFS= read -r repo; do
  [ "$repo" = "macinsight-docker/renovate" ] && continue

  name="${repo#*/}"
  echo "Processing $repo"
  gh repo clone "$repo" "$workdir/$name" -- --quiet

  (
    cd "$workdir/$name"

    cat > renovate.json <<'EOF'
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>macinsight-docker/renovate"]
}
EOF

    git add renovate.json
    git commit -m "chore: add centralized Renovate configuration"
    git push origin HEAD
  )
done
