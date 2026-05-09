#!/bin/bash
#
# This script is designed for debloating
# and installing microG on Samsung devices
# The code is quite simple and straightforward,
# so I hope you won't have any trouble understanding
# it without documentation. Be careful and have fun!
#

if [[ $# != 1 ]]; then
    echo "Usage: $0 <path-to-AP.tar>"
    exit 1
fi

AP=$(realpath "$1")
SCRIPT_ROOT_DIR=$(realpath $(dirname "$0"))
PARENT_WORKING_DIRECTORY=$PWD
ROOT_DIR=$(realpath clean_super_$(date +%s))
MICROG_DIR=$ROOT_DIR/microG

CONFIG_FILES=('samsung_list.conf' 'google_list.conf')

REQUIRED_COMMANDS=('rg' 'java' 'tar' 'lz4' 'simg2img' 'lpunpack' 'fsck.erofs' 'aapt')

for cmd in "${REQUIRED_COMMANDS}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        echo -e "\e[1;31mError: command '$cmd' not found\e[0m"
        exit 1
    fi
done

mkdir "$ROOT_DIR"

echo -e '\e[3;36m[+] Extracting super.img.lz4 from AP\e[0m'
tar -xf "$AP" -C "$ROOT_DIR" super.img.lz4 &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive. Are u sure that is the correct path?\e[0m'
    exit 1
fi

echo -e "\e[3;36m[+] Removing working directory\e[0m"
rm -rf "$ROOT_DIR"

echo -e "\e[3;36m[+] Done. Now you can flash it through heimdall or pack to AP.tar and flash it with Odin\e[0m"
