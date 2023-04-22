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


# Set environment variables
export DEBIAN_FRONTEND="noninteractive"

# Prepare for further tasks
function prepare_apt() {
    # Update packages list
    apt-get update

    # Install jq (required to easily extract variables from defaults.json)
    apt-get install -y --no-install-recommends jq gnupg

    # Add ngNOS repository to the system
    local APT_NGNOS_MIRROR=`jq --raw-output .ngnos_mirror /tmp/defaults.json`
    local APT_NGNOS_BRANCH=`jq --raw-output .ngnos_branch /tmp/defaults.json`
    local APT_ADDITIONAL_REPOS=`jq --raw-output .additional_repositories[] /tmp/defaults.json`
    local RELEASE_TRAIN=`jq --raw-output .release_train /tmp/defaults.json`

    if [[ "${RELEASE_TRAIN}" == "crux" ]]; then
        echo -e "deb ${APT_NGNOS_MIRROR}/ngnos ${APT_NGNOS_BRANCH} main\ndeb ${APT_NGNOS_MIRROR}/debian ${APT_NGNOS_BRANCH} main\n${APT_ADDITIONAL_REPOS}" > /etc/apt/sources.list.d/ngnos.list
    fi

    if [[ "${RELEASE_TRAIN}" == "equuleus" || "${RELEASE_TRAIN}" == "sagitta" ]]; then
        echo -e "deb ${APT_NGNOS_MIRROR} ${APT_NGNOS_BRANCH} main\n${APT_ADDITIONAL_REPOS}" > /etc/apt/sources.list.d/ngnos.list
        # Add backports repository
        echo -e "deb http://deb.debian.org/debian buster-backports main\ndeb http://deb.debian.org/debian buster-backports non-free non-free-firmware" >> /etc/apt/sources.list.d/ngnos.list
    fi

    # Copy additional repositories and preferences, if persented
    if grep -sq deb /tmp/*.list.chroot; then
        cat /tmp/*list.chroot >> /etc/apt/sources.list.d/ngnos.list
    fi
    if grep -sq Package /tmp/*.pref.chroot; then
        for pref_file in /tmp/*.pref.chroot; do
            cat $pref_file >> /etc/apt/preferences.d/10ngnos
            echo -e "\n" >> /etc/apt/preferences.d/10ngnos
        done
    fi

    # Add GPG keys
    if [[ ! -e /etc/apt/trusted.gpg.d/ngnos.gpg ]]; then
        echo "Adding GPG keys to the system"
        cat /tmp/*.key.chroot | apt-key --keyring /etc/apt/trusted.gpg.d/ngnos.gpg add -
    fi

    # Update packages list
    apt-get -o Acquire::Check-Valid-Until=false update
}

# Cleanup APT after finish
function cleanup_apt() {
    # delete jq tool
    dpkg -P jq
    # Clear APT cache
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm /etc/apt/sources.list.d/ngnos.list
    if [[ -e /etc/apt/preferences.d/10ngnos ]]; then
        rm /etc/apt/preferences.d/10ngnos
    fi
}

# Filter list elements
function filter_list() {
    local list_elements=("${!1}")
    local filtered_elements=("${!2}")
    local list_elements_filtered

    for list_element in "${list_elements[@]}"; do
        local filtered=""

        for filtered_element in "${filtered_elements[@]}"; do
            if [[ ${list_element} =~ ${filtered_element} ]]; then
                filtered=True
            fi
        done

        if [[ -z "${filtered}" ]]; then
            list_elements_filtered+=("${list_element}")
        fi
    done
    echo ${list_elements_filtered[@]}
}
