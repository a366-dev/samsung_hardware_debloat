#!/bin/bash
#
# This script is designed to generate
# a list of APK files that script
# considers as "verified". Use only
# during development
# 

if [[ $# != 1 ]]; then
    echo "Usage: $0 <path-to-product+system+system_ext-folder>"
    exit 1
fi

ROOT=$(realpath "$1")
SCRIPT_ROOT_DIR=$(realpath $(dirname "$0"))
PARENT_WORKING_DIRECTORY=$PWD

cd "$ROOT"
find product system/system system_ext -maxdepth 2 -path "*/app/*" -o -path "*/priv-app/*" -type d | sort > $SCRIPT_ROOT_DIR/checked.apps
cd "$PARENT_WORKING_DIRECTORY"
