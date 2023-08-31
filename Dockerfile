# SPDX-License-Identifier: MIT
# Author: Nils Freydank <nils.freydank@posteo.de>
#
# ===========================================================================
#   Update the source image.
# ===========================================================================
FROM gentoo/stage3:amd64-nomultilib-systemd as bootstrap
# Migrate to a merged-usr form.
RUN emerge --quiet-build=y --oneshot merge-usr
RUN merge-usr
RUN eselect profile set "default/linux/amd64/17.1/no-multilib/systemd/merged-usr"
# Replace /etc/portage/make.conf.
RUN rm --one-file-system /etc/portage/make.conf
COPY make.conf /etc/portage/make.conf
RUN chown root:root -R /etc/portage/make.conf
# Add overlays in /var/db/repos.
COPY repos.conf /etc/portage/repos.conf
RUN chown root:root -R /etc/portage/make.conf
# Update the compiler and glibc. Switch to the new gcc then and print the version.
RUN emerge --oneshot --usepkg sys-devel/gcc:13 sys-libs/glibc
RUN eselect gcc set x86_64-pc-linux-gnu-13 && source /etc/profile && gcc --version
# Update libtool after the compiler update.
RUN emerge --oneshot sys-devel/libtool
# Rebuild the whole world set, probably mostly with binpkgs.
RUN emerge --emptytree --verbose --usepkg @world
# Install further toolchains
RUN emerge --usepkg --noreplace dev-lang/rust dev-lang/go \
    @rust-rebuild @golang-rebuild
# Rebuild packages if necessary.
RUN emerge @preserved-rebuild
# Fix stuff after perl upgrades
RUN perl-cleaner --reallyall

# ===========================================================================
#   Clean up the image.
# ===========================================================================
# Unmerge stuff that is not needed.
RUN emerge --depclean
RUN rm --verbose --recursive --preserve-root /var/tmp/

# ===========================================================================
#   Create the new image
# ===========================================================================
FROM scratch
COPY --from=bootstrap / /

# vim:fileencoding=utf-8:ts=4:syntax=dockerfile:expandtab
