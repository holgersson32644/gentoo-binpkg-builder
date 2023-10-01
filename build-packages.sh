#!/bin/bash
# SPDX-License-Identifier: MIT
# Author: Nils Freydank <nils.freydank@posteo.de>
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
set -uxa

REGISTRY="${REGISTRY:-git.holgersson.xyz/gentoo-related/gentoo-binpkg-builder}"
VERSION="${VERSION:-latest}"

REPOS="${REPOS:-/var/db/repos}"
DISTFILES="${DISTFILES:-/var/cache/distfiles-podman-1}"
BINPKG="${BINPKG:-/var/cache/packages-podman-1}"
LOGDIR="${LOGDIR:-$(pwd)/log}"
PACKAGE_USE="${PACKAGE_USE:-$(pwd)/package.use}"

PODMAN_BUILD_ARGS=(
    # Do not leak the host's /etc/host into the container.
    --no-hosts
    # Remove the container after usage.
    --rm
    # Allow interactive questsions by portage
    -ti
    # Limit the memory to be used.
    --memory=20G
    # memory-swap is the sum of RAM and swap.
    --memory-swap=21G
    --shm-size=2G
    # Share the portage configuration.
    -v "${PACKAGE_USE}:/etc/portage/package.use:ro"
    # Share the gentoo repo, overlays etc.
    -v "${REPOS}:/var/db/repos:ro"
    # Share the world file, too.
    -v "./world:/var/lib/portage/world:ro"
    # Share the distfiles, i.e. typically source archives.
    -v "${DISTFILES}:/var/cache/distfiles:rw,U"
    # Share the binpkgs r/w cache.
    -v "${BINPKG}:/var/cache/packages:rw,U"
    # Keep the logs out of the container.
    -v "${LOGDIR}:/var/log:rw,U"
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

_mkdir "${REPOS}"
_mkdir "${DISTFILES}"
_mkdir "${BINPKG}"
_mkdir "${LOGDIR}"

podman run "${PODMAN_BUILD_ARGS[@]}" "${REGISTRY}:${VERSION}" \
    bash -c "emerge --usepkg --newuse --keep-going --oneshot --deep --update @world \
    && emerge @golang-rebuild @rust-rebuild \
    && eclean-pkg --deep" \
    || exit_err "Could not build packages."

podman unshare chown -R "0:0" "${LOGDIR}" || exit_err "Could not fix access right post build."

# vim:fileencoding=utf-8:ts=4:syntax=bash:expandtab
