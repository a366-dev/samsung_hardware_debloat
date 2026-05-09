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

REQUIRED_COMMANDS=('rg' 'java' 'tar' 'lz4' 'simg2img' 'lpunpack' 'fsck.erofs' 'aapt' 'find')

for cmd in "${REQUIRED_COMMANDS}"; do
    if ! command -v "${cmd}" &> /dev/null; then
        echo -e "\e[1;31mError: command '$cmd' not found\e[0m"
        exit 1
    fi
done

mkdir "$ROOT_DIR"

echo -e '\e[3;36m[+] Downloading latest microG\e[0m'
mkdir "$MICROG_DIR"

curl -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/microg/GmsCore/releases/latest > "$MICROG_DIR/GmsCore.json"
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to get latest release\e[0m'
    exit 1
fi

curl -L $(cat "$MICROG_DIR/GmsCore.json" | rg -e "\"(https://.*com.google.android.gms-[^-]*-hw.apk)\"" -or '$1') -o "$MICROG_DIR/GmsCore.apk"
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to download GmsCore.apk\e[0m'
    exit 1
fi

curl -L $(cat "$MICROG_DIR/GmsCore.json" | rg -e "\"(https://.*com.android.vending-[^-]*-hw.apk)\"" -or '$1') -o "$MICROG_DIR/FakeStore.apk"
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to download FakeStore.apk\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Generating ROM permissions\e[0m'
bash "$SCRIPT_ROOT_DIR/dl-perm-list.sh" &> /dev/null

echo -e '\e[3;36m[+] Generating XML files\e[0m'
echo -e '   \e[3;36m[*] Generating GmsCore.apk XMLs\e[0m'
bash "$SCRIPT_ROOT_DIR/generate-perm-xml.sh" "$MICROG_DIR/GmsCore.apk" &> /dev/null
echo -e '   \e[3;36m[*] Generating FakeStore.apk XMLs\e[0m'
bash "$SCRIPT_ROOT_DIR/generate-perm-xml.sh" "$MICROG_DIR/FakeStore.apk" &> /dev/null
mv "$PARENT_WORKING_DIRECTORY/output" "$MICROG_DIR/perms"
rm -rf "$SCRIPT_ROOT_DIR/data"

echo -e '\e[3;36m[+] Extracting super.img.lz4 from AP\e[0m'
tar -xf "$AP" -C "$ROOT_DIR" super.img.lz4 &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive. Are u sure that is the correct path?\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Extracting super.img from super.img.lz4\e[0m'
lz4 -d "$ROOT_DIR/super.img.lz4" "$ROOT_DIR/super.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Deleting super.img.lz4 as unneeded\e[0m'
rm "$ROOT_DIR/super.img.lz4"

echo -e '\e[3;36m[+] Extracting super.raw\e[0m'
simg2img "$ROOT_DIR/super.img" "$ROOT_DIR/super.raw" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi
echo -e '\e[3;36m[+] Deleting super.img as unneeded\e[0m'
rm "$ROOT_DIR/super.img"

echo -e '\e[3;36m[+] Finally extracting super.raw\e[0m'
mkdir "$ROOT_DIR/super"
lpunpack "$ROOT_DIR/super.raw" "$ROOT_DIR/super" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

mkdir "$ROOT_DIR/super/product" "$ROOT_DIR/super/system" "$ROOT_DIR/super/system_ext"

echo -e '\e[3;36m[+] Extracting product_a.img\e[0m'
fsck.erofs --extract="$ROOT_DIR/super/product" "$ROOT_DIR/super/product_a.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Extracting system_a.img\e[0m'
fsck.erofs --extract="$ROOT_DIR/super/system" "$ROOT_DIR/super/system_a.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Extracting system_ext_a.img\e[0m'
fsck.erofs --extract="$ROOT_DIR/super/sytem_ext" "$ROOT_DIR/super/system_ext_a.img" &> /dev/null
if [[ $? != 0 ]]; then
    echo -e '\e[1;31m[-] Failed to extract the archive\e[0m'
    exit 1
fi

echo -e '\e[3;36m[+] Scanning for unchecked applications\e[0m'

cd "$ROOT_DIR/super"
find product system/system system_ext -maxdepth 2 -path "*/app/*" -o -path "*/priv-app/*" -type d | sort > all.apps

UNCHECKED_APPS=$(comm -23 all.apps "$SCRIPT_ROOT_DIR/checked.apps")

cd $PARENT_WORKING_DIRECTORY

if [[ -n "$UNCHECKED_APPS" ]]; then
    for app in $UNCHECKED_APPS; do
        echo -e "\n\e[31m[!] WARNING: New unverified app detected:\e[0m"
        echo -e "----------------------------------------"
        echo -e "\e[1;32m$app\e[0m"
        echo -e "----------------------------------------"
        echo -e "Action: (d)elete, (k)eep, (w)hat are u want, keep it and dont ask me again, or (s)kip and decide manually? [d/k/s]"
        read -sn 1 action

        case $action in
            d)
                echo "[+] Deleting $app\e[0m"
                rm -rf "$ROOT_DIR/super/$app"
                ;;
            k)
                echo "[+] Whitelising $app\e[0m"
                echo "$app" >> "$SCRIPT_ROOT_DIR/checked.apps"
                sort -u -o "$SCRIPT_ROOT_DIR/checked.apps" "$SCRIPT_ROOT_DIR/checked.apps"
                ;;
            w)
                break
                ;;
            s)
                echo "\e[3;36m[+] Understood. Exiting\e[0m"
                exit 0
        esac
    done
fi

echo -e '\e[3;36m[+] Starting multimodule cleanup process\e[0m'
for config in "${CONFIG_FILES[@]}"; do
    config_path="$SCRIPT_ROOT_DIR/$config"
    if [ ! -f "$config_path" ]; then
        echo -e "\e[1;31m[-] Config file $config not found, skipping\e[0m"
        continue
    fi

    echo -e "\e[3;36m[#] Processing module: $config\e[0m"

    grep -v '^#' "$config_path" | grep -v '^$' | while read -r line; do
        DIR_TO_REMOVE=$(echo $line | awk '{print $1}')
        DIR_TO_REMOVE_PATH="$ROOT_DIR/super/$DIR_TO_REMOVE"

        if [ -d "$DIR_TO_REMOVE_PATH" ]; then
            echo -e "  \e[3;36m[+] Removing: $DIR_TO_REMOVE\e[0m"
            echo -e "      \e[1;34m[*] Deleting all permissions\e[0m"
            APK_NAME=$(basename "$DIR_TO_REMOVE")
            PACKAGE_NAME=$(aapt dump badging "$DIR_TO_REMOVE_PATH/$APK_NAME".apk | rg -e "package: name=\'([^\']+)" -or '$1')
            ETC_PATH="$(dirname $(dirname "$DIR_TO_REMOVE_PATH"))/etc"
            SYSCONFIG_PERMISSIONS_FILE=$(grep -rl "\"$PACKAGE_NAME\"" "$ETC_PATH/permissions" | head -n 1)
            if [[ -n "$SYSCONFIG_PERMISSIONS_FILE" ]]; then
                echo -e "          \e[1;32m[+] Removing: $SYSCONFIG_PERMISSIONS_FILE\e[0m"
                rm -rf "$SYSCONFIG_PERMISSIONS_FILE"
            else
                echo -e "          \e[1;31m[-] No XML file found in $ETC_PATH/permissions\e[0m"
            fi
            PERMISSIONS_FILE=$(grep -rl "\"$PACKAGE_NAME\"" "$ETC_PATH/permissions" | head -n 1)
            if [[ -n "$PERMISSIONS_FILE" ]]; then
                echo -e "          \e[1;32m[+] Removing: $PERMISSIONS_FILE\e[0m"
                rm -rf "$PERMISSIONS_FILE"
            else
                echo -e "          \e[1;31m[-] No XML file found in $ETC_PATH/permissions\e[0m"
            fi
            DEFAULT_PERMISSIONS_FILE=$(grep -rl "\"$PACKAGE_NAME\"" "$ETC_PATH/default-permissions" | head -n 1)
            if [[ -n "$DEFAULT_PERMISSIONS_FILE" ]]; then
                echo -e "          \e[1;32m[+] Removing: $DEFAULT_PERMISSIONS_FILE\e[0m"
                rm -rf "$DEFAULT_PERMISSIONS_FILE"
            else
                echo -e "          \e[1;31m[-] No XML file found in $ETC_PATH/default-permissions\e[0m"
            fi
            rm -rf "$DIR_TO_REMOVE_PATH"
        else
            echo -e "  \e[1;31m[?] Not found: $DIR_TO_REMOVE\e[0m"
        fi
    done
done

echo -e "\e[3;36m[+] Adding microG\e[0m"
echo -e "   \e[3;36m[*] Adding GmsCore\e[0m"
mkdir "$ROOT_DIR/super/product/priv-app/GmsCore"
mv "$MICROG_DIR/GmsCore.apk" "$ROOT_DIR/super/product/priv-app/GmsCore"
echo -e "   \e[3;36m[*] Adding FakeStore\e[0m"
mkdir "$ROOT_DIR/super/product/priv-app/FakeStore"
mv "$MICROG_DIR/FakeStore.apk" "$ROOT_DIR/super/product/priv-app/FakeStore"
echo -e "   \e[3;36m[*] Adding XMLs\e[0m"
mv "$MICROG_DIR/perms/"* "$ROOT_DIR/super/product/etc/permissions"

echo -e "\e[3;36m[+] Packing FW back\e[0m"
echo -e "   \e[3;36m[*] Packing product.img\e[0m"
mkfs.erofs -zlz4hc "$ROOT_DIR/super/product_a.img" "$ROOT_DIR/super/product" --all-root &> /dev/null
echo -e "   \e[3;36m[*] Packing system.img\e[0m"
mkfs.erofs -zlz4hc "$ROOT_DIR/super/system_a.img" "$ROOT_DIR/super/system" --all-root &> /dev/null
echo -e "   \e[3;36m[*] Packing system_ext.img\e[0m"
mkfs.erofs -zlz4hc "$ROOT_DIR/super/system_ext_a.img" "$ROOT_DIR/super/system_ext" --all-root &> /dev/null

echo -e "\e[3;36m[+] Removing working directory\e[0m"
rm -rf "$ROOT_DIR"

echo -e "\e[3;36m[+] Done. Now you can flash it through heimdall or pack to AP.tar and flash it with Odin\e[0m"
