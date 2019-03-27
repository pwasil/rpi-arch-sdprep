#!/bin/bash

# Load configuration
source ./rpi-arch-sdprep.conf || echo "[err] missing config file, this won't work..."

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
    echo "[err] you need to be root to run this. exitting..."
    exit 1
fi

if [[ ! -b "/dev/${block_device_name}" ]]; then
    echo "[err] missing or incorrect device name"
    exit 1
fi

if [[ ! -f "${file_image_dir}/${file_image_name}" ]]; then
    if [[ ! -d  "${file_image_dir}" ]]; then
        echo "[log] creating archlinux image ${file_image_dir}"
        mkdir --parent "${file_image_dir}"
    fi
    echo "[log] getting archlinux image"
    wget --directory-prefix="${file_image_dir}" "${mirror_url}/${file_image_name}"
fi

# Umount any already mounted drives
for i in "$(ls /dev/${block_device_name}*)"; do
    echo "[log] umounting "${i}" ..."
    umount "${i}"
done

# Partition the device
sfdisk "/dev/${block_device_name}" << EOF
label: dos
type=c, size=128M
type=83
EOF

# Go to temp build directory
temp_dir="$(mktemp --directory)"
echo "[log] changing to temp directory ${temp_dir}"
cd "${temp_dir}"

# Create and mount filesystems
yes | mkfs.vfat "/dev/${block_device_name}${block_device_part_1}" && mkdir "boot" && mount "/dev/${block_device_name}${block_device_part_1}" "boot"
yes | mkfs.ext4 "/dev/${block_device_name}${block_device_part_2}" && mkdir "root" && mount "/dev/${block_device_name}${block_device_part_2}" "root"

# Unpack the image
bsdtar -xpf "${file_image_dir}/${file_image_name}" -C root && sync
mv root/boot/* boot

# Copy the post install scripts to SD card
cd -
cp rpi-arch-sdprep-postinstall.sh ${temp_dir}/root/root/
cp rpi-arch-sdprep.conf ${temp_dir}/root/root/
echo 'PermitRootLogin yes' >> ${temp_dir}/root/etc/ssh/sshd_config
cat ./nsswitch.conf > ${temp_dir}/root/etc/nsswitch.conf

# Exit
umount "${temp_dir}/boot" "${temp_dir}/root"
exit 0