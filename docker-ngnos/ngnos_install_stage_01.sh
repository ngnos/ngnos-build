#!/bin/bash

# Copyright (C) 2020 VyOS maintainers and contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 or later as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Stage 1 - install dependencies

# load common functions
. ngnos_install_common.sh

echo "Configuring APT repositories"
prepare_apt

# Get list of ngNOS packages
ngnos_packages=(`apt-cache -i depends ngnos-world | awk '/Depends:/ { printf("%s ", $2) }'`)

# Do not analyze packages, which we do not need in Docker
ngnos_packages_filter=(
    "ngnos-intel*"
    )
ngnos_packages_filtered=("$(filter_list ngnos_packages[@] ngnos_packages_filter[@])")
echo "Packages for dependency analyzing: ${ngnos_packages_filtered[@]}"

# Get list of all dependencies
ngnos_dependencies=(`apt-get -s install --no-install-recommends ${ngnos_packages_filtered[@]} | awk '/Inst/ { printf("%s ", $2) }'`)

# Do not install unnecessary
ignore_list=(
    "dosfstools"
    "parted"
    "libparted*"
    "efibootmgr"
    "gdisk"
    "grub-*"
    "laptop-detect"
    "installation-report"
    "tshark"
    "wireshark*"
    "mdadm"
    "keepalived"
    "libheartbeat2"
    "bmon"
    "crda"
    "ipvsadm"
    "iw"
    "pptpd"
    "cluster-glue"
    "resource-agents"
    "heartbeat"
    )

# Get list of packages from NGNOS repository
if ls /var/lib/apt/lists/*ngnos*Packages* | grep -q gz$; then
    arch_cat="zcat"
fi
if ls /var/lib/apt/lists/*ngnos*Packages* | grep -q lz4$; then
    arch_cat="lz4cat"
    echo "Installing lz4"
    apt-get install -y --no-install-recommends lz4
fi
ngnos_repo_packages=(`$arch_cat /var/lib/apt/lists/*ngnos*Packages* | awk '/Package:/ { printf("%s\n",$2) }'`)
if [[ "${arch_cat}" == "lz4cat" ]]; then
    echo "Removing lz4"
    apt-get purge -y lz4
fi
# Add them to ignore list - we do not need anything from ngNOS in this layer of image
ignore_list=("${ignore_list[@]}" "${ngnos_repo_packages[@]}")

# Remove every ignore list item from installation list
ngnos_dependencies_filtered=("$(filter_list ngnos_dependencies[@] ignore_list[@])")

# Add missed dependencies
ngnos_dependencies_filtered+=(
    "liburi-perl"
    "locales"
    "libcap-ng0"
    "libnss-myhostname"
    "dbus"
    )

echo "Dependencies filtered list: ${ngnos_dependencies_filtered[@]}"

# Install delependencies
echo "Installing dependencies"
apt-get install -y --no-install-recommends ${ngnos_dependencies_filtered[@]}

echo "Deconfiguring APT repositories"
cleanup_apt


exit 0
