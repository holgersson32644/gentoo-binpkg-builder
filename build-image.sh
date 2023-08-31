#!/bin/bash
# SPDX-License-Identifier: MIT
# Author: Nils Freydank <nils.freydank@posteo.de>
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
set -uxa

GPG_SIGNING_KEY="${GPG_SIGNING_KEY:-0x0F1DEAB2D36AD112}"

REGISTRY="${REGISTRY:-git.holgersson.xyz/gentoo-related/gentoo-binpkg-builder}"
VERSION="${VERSION:-$(date --utc +%Y%m%d_%H%M%S)}"
IMAGE_TAG="${REGISTRY}:${VERSION}"

REPOS="${REPOS:-/var/db/repos}"
DISTFILES="${DISTFILES:-/var/cache/distfiles-podman-1}"
BINPKG="${BINPKG:-/var/cache/packages-podman-1}"
LOGDIR="${LOGDIR:-$(pwd)/log}"
DOCKER_FILE="${DOCKER_FILE:-$(pwd)/Dockerfile}"

podman_build_args=(
    # Do not leak the host's /etc/host into the container.
    --no-hosts
    # Limit the memory to be used.
    --memory=20G
    --memory-swap=1G
    --shm-size=2G
    # Share the gentoo repo, overlays etc.
    -v "${REPOS}:/var/db/repos:ro"
    # Share the distfiles, i.e. typically source archives.
    -v "${DISTFILES}:/var/cache/distfiles:rw,U"
    # Share the binpkgs r/w cache.
    -v "${BINPKG}:/var/cache/packages:rw,U"
    # Keep the logs out of the container.
    -v "${LOGDIR}:/var/log:rw,U"
    # Use the given OCI file/Dockerfile.
    -f "${DOCKER_FILE}"
    # Tag the generated image.
    -t "${IMAGE_TAG}"
    # Label the image.
    --label="gentoo-nfr-${IMAGE_TAG}"
    # Sign the image.
    #--sign-by="${GPG_SIGNING_KEY}"
    # Rebuild everything w/o cache.
    --no-cache
)

mkdir -p "${REPOS}"
mkdir -p "${DISTFILES}"
mkdir -p "${BINPKG}"
mkdir -p "${LOGDIR}"

podman pull gentoo/stage3:amd64-nomultilib-systemd
podman build "${podman_build_args[@]}"

# Update the tag 'latest'.
podman tag rm "${REGISTRY}:latest"
podman tag "${REGISTRY}:${VERSION}" "${REGISTRY}:latest"

# vim:fileencoding=utf-8:ts=4:syntax=bash:expandtab
