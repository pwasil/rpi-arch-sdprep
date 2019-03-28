#!/bin/bash

# Set message templates
MSG_INFO="\e[32m[INFO]\e[0m"
MSG_WARN="\e[33m[WARN]\e[0m"
MSG_FATAL="\e[31m[FATAL]\e[0m"

# Load configuration
source ./rpi-arch-sdprep.conf || echo -e "${MSG_WARN} Config file not found. Have you passed all args?"

# Get command line args that if added, will override the vars from config file
while [[ $# -gt 0 ]]; do
    case "${1}" in
        -d|--block-device) block_device_name="${2}"; shift ;;
        -p1|--part-1) block_device_part_1="${2}"; shift ;;
        -p2|--part-2) block_device_part_2="${2}"; shift ;;
    esac
done

# Check if all args are set
if [[ "$(whoami)" != "root" ]]; then
    echo -e "${MSG_FATAL} You need to be root to run this. Exitting..."
    exit 1
fi

if [[ "$(cat /sys/class/block/${block_device_name}/removable)" != "1" ]]; then
    echo -e "${MSG_WARN} /dev/${block_device_name} is not a removable device!"
    echo -e "${MSG_WARN} This script will erase all data on ${block_device_name}"
    echo -e "${MSG_WARN} Make sure that you know what you are doing!"
    echo -en "${MSG_WARN} Do you want to continue? Press enter or Ctrl+C to abort"
    read
fi

if [[ ! -b "/dev/${block_device_name}" ]]; then
    echo -e "${MSG_FATAL} missing or incorrect device name"
    exit 1
fi

if [[ ! -f "${file_image_dir}/${file_image_name}" ]]; then
    if [[ ! -d  "${file_image_dir}" ]]; then
         echo "${MSG_INFO} creating archlinux image ${file_image_dir}"
        mkdir --parent "${file_image_dir}"
    fi
    echo "[log] getting archlinux image"
    wget --directory-prefix="${file_image_dir}" "${mirror_url}/${file_image_name}"
fi

# Temporarily redirect stdout of all commands to logfile
exec 3>&1 4>&2 > ./rpi-arch-sdprep.log 2>&1

# Umount any already mounted drives
for i in $(ls /dev/${block_device_name}*); do
    >&3 echo -e "${MSG_INFO} Umounting ${i}..."
    umount "${i}"
done

# Partition the device
>&3 echo -e "${MSG_INFO} Creating partitions"
sfdisk "/dev/${block_device_name}" << EOF
label: dos
type=c, size=128M
type=83
EOF

# Go to temp build directory
temp_dir="$(mktemp --directory)"
>&3 echo -e "${MSG_INFO} Changing to temp directory ${temp_dir}"
cd "${temp_dir}"

# Create and mount filesystems
>&3 echo -e "${MSG_INFO} Creating filesystems"
yes | mkfs.vfat "/dev/${block_device_name}${block_device_part_1}" && mkdir "boot" && mount "/dev/${block_device_name}${block_device_part_1}" "boot"
yes | mkfs.ext4 "/dev/${block_device_name}${block_device_part_2}" && mkdir "root" && mount "/dev/${block_device_name}${block_device_part_2}" "root"

# Unpack the image
>&3 echo -e "${MSG_INFO} Unpacking the OS image"
bsdtar -xpf "${file_image_dir}/${file_image_name}" -C root
mv root/boot/* boot

# Copy the post install scripts to SD card
>&3 echo -e "${MSG_INFO} Copying post install scripts"
cd -
cp rpi-arch-sdprep-postinstall.sh ${temp_dir}/root/root/
cp rpi-arch-sdprep.conf ${temp_dir}/root/root/
echo 'PermitRootLogin yes' >> ${temp_dir}/root/etc/ssh/sshd_config
cat nsswitch.conf > ${temp_dir}/root/etc/nsswitch.conf

# Flush all buffers
>&3 echo -e "${MSG_INFO} Flushing all buffers before umounting. This may take some time..."
sync

# Exit
>&3 echo -e "${MSG_INFO} Umounting partitions"
umount "${temp_dir}/boot" "${temp_dir}/root"

# Restore stdout and stderr
exec 1>&3 2>&4

# Exit
echo -e "${MSG_INFO} All is good, exitting..."
exit 0