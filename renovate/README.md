# Renovate

This directory contains the shared Renovate preset and a helper script that was
used to add it to the former per-service repositories.

## Configure and run

`default.json` is the shared policy. The root `renovate.json` applies that
policy to this repository, and the per-stack configuration files retain the
same preset reference for a future split-out. Patch and minor updates are
automerged after a three-day release-age delay and required checks pass. Minor
and major pull requests include available upstream changelogs; major updates
also require Dependency Dashboard approval and `macinsight` review. Pull
requests use conventional `chore(deps)` commits, include a dependency table,
and are limited to ten open and three new pull requests per hour. Renovate
labels every pull request and categorizes Docker, GitHub Actions, patch, minor,
major, and automerge candidates.

The preset uses Europe/Berlin time and keeps patch, minor, and major updates in
separate pull requests. It intentionally does not import the reference
configuration's Terraform, Ansible, Python, or unrelated container-image rules:
this repository currently manages Docker Compose images only. Provide Renovate
credentials at runtime through environment variables or an external secret
store.

`reno.sh` still targets the former `macinsight-docker` organization. Treat it
as migration history, not as the normal way to update this consolidated
repository.

Do not commit access tokens, private repository URLs, or generated Renovate
state.
