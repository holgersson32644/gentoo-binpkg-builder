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

ARCH="${ARCH:-amd64}"
MICROARCH="${MICROARCH:-amd64}"
OCI_ARCH="${OCI_ARCH:-linux/amd64}"

PODMAN_BUILD_ARGS=(
    # Do not leak the host's /etc/host into the container.
    --no-hosts
    # Limit the memory to be used.
    --memory=20G
    # memory-swap is the sum of RAM and swap.
    --memory-swap=21G
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
    # Add details about the architecture.
	--build-arg ARCH="${ARCH}"
	--build-arg MICROARCH="${MICROARCH}"
	--platform "${OCI_ARCH}"
    # Tag the generated image.
    -t "${IMAGE_TAG}"
    -t "${REGISTRY}:latest"
    # Label the image.
    --label="gentoo-nfr-${IMAGE_TAG}"
    # sign the image.
    #--sign-by="${GPG_SIGNING_KEY}"
    # Rebuild everything w/o cache.
    --no-cache
)

exit_err()
{
  echo "${@}"
  exit 1
}

_mkdir()
{
  mkdir -p "${@}" || exit_err "Could not create dir ${@}."
}

# === Prepare all directories.
_mkdir "${REPOS}"
_mkdir "${DISTFILES}"
_mkdir "${BINPKG}"
_mkdir "${LOGDIR}"

# === Fetch the stage3 file (and verify it).
# Note: This uses some nasty string manipulation assuming a certain structure.
#       If upstream changes the format, things will break here, again.
SERVER="https://ftp-osl.osuosl.org/pub/gentoo/releases/${ARCH}/autobuilds"
MY_STAGE3="latest-stage3-amd64-nomultilib-systemd-mergedusr.txt"

# Fetch the stage3 archive and its signature.
curl -sLC- -O --output-dir "${DISTFILES}" "${SERVER}/${MY_STAGE3}" \
  || exit_err "Could not download the pointer file for the stage3 archive."
gpg --verify "${DISTFILES}/${MY_STAGE3}" \
  || exit_err "Could not verify the download pointer file."

LATEST_ARCHIVE="$(grep $(echo ${MY_STAGE3} | sed 's/latest-//;s/.txt//') ${DISTFILES}/${MY_STAGE3} | cut -f1 -d' ')"
ARCHIVE_FILE_NAME="$(echo ${LATEST_ARCHIVE} | cut -f2 -d'/')"

curl -sLC- -O --output-dir "${DISTFILES}" "${SERVER}/${LATEST_ARCHIVE}" \
  || exit_err "Could not download the stage3 archive."
curl -sLC- -O --output-dir "${DISTFILES}" "${SERVER}/${LATEST_ARCHIVE}.asc" \
  || exit_err "Could not download the stage3 archive signature."

# Verify the signature.
gpg --verify "${DISTFILES}/${ARCHIVE_FILE_NAME}"{.asc,} \
  || exit_err "Could not verify the stage3 archive."

# === Remove the old tag 'latest'.
podman tag rm "${REGISTRY}:latest" # Do not exit_err here. At least on first run
                                   # there is no latest tag to delete.

# === Build the new image.
podman build --build-arg=ROOTFS_FILENAME="${DISTFILES}/${ARCHIVE_FILE_NAME}" \
  "${PODMAN_BUILD_ARGS[@]}" || exit_err "Build failed."

# vim:fileencoding=utf-8:ts=4:syntax=bash:expandtab
