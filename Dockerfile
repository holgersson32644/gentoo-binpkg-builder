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
# Update the compiler
RUN emerge --oneshot --usepkg sys-devel/gcc:13
RUN eselect gcc set x86_64-pc-linux-gnu-13 && source /etc/profile
# Update libtool after the compiler update.
RUN emerge --oneshot sys-devel/libtool
# Rebuild the whole world set, probably mostly with binpkgs.
RUN emerge --emptytree --verbose --usepkg @world
# Install further toolchains
RUN emerge --usepkg --noreplace dev-lang/rust dev-lang/go \
    @rust-rebuild @golang-rebuild
# Rebuild packages if necessary.
RUN emerge @preserved-rebuild

# ===========================================================================
#   Clean up the image.
# ===========================================================================
RUN rm --verbose --recursive --preserve-root /var/tmp/

# ===========================================================================
#   Create the new image
# ===========================================================================
FROM scratch
COPY --from=bootstrap / /

# vim:fileencoding=utf-8:ts=4:syntax=dockerfile:expandtab
