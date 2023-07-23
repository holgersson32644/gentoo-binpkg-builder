#!/bin/bash
# SPDX-License-Identifier: MIT
# Author: Nils Freydank <nils.freydank@posteo.de>
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
set -uxa

mapfile -t EMERGE_CALL_PARAMETERS <<< "${@}"

REGISTRY="git.holgersson.xyz/gentoo-related/gentoo-binpkg-builder"
VERSION="latest"
IMAGE_TAG="${REGISTRY}:${VERSION}"

REPOS="${REPOS:-/var/db/repos}"
DISTFILES="${DISTFILES:-/var/cache/distfiles-podman-1}"
BINPKG="${BINPKG:-/var/cache/packages-podman-1}"
LOGDIR="${LOGDIR:-$(pwd)/logs}"
PACKAGE_USE="${PACKAGE_USE:-$(pwd)/package.use}"

podman_build_args=(
    # Remove the container after usage.
    --rm
    # Allow interactive questsions by portage
    -ti
    # Limit the memory to be used.
    --memory=20G
    --memory-swap=1G
    --shm-size=2G
    # Share the portage configuration.
    -v "${PACKAGE_USE}:/etc/portage/package.use:ro"
    # Share the gentoo repo, overlays etc.
    -v "${REPOS}:/var/db/repos:ro"
    # Share the distfiles, i.e. typically source archives.
    -v "${DISTFILES}:/var/cache/distfiles:rw,U"
    # Share the binpkgs r/w cache.
    -v "${BINPKG}:/var/cache/packages:rw,U"
    # Keep the logs out of the container.
    -v "${LOGDIR}:/var/log:rw,U"
)

mkdir -p "${REPOS}"
mkdir -p "${DISTFILES}"
mkdir -p "${BINPKG}"
mkdir -p "${LOGDIR}"

podman run "${podman_build_args[@]}" "${REGISTRY}:${VERSION}" \
    emerge --oneshot --keep-going ${EMERGE_CALL_PARAMETERS[@]}

# vim:fileencoding=utf-8:ts=4:syntax=bash:expandtab
