# rpi-arch-sdprep
A simple tool to prepare and initially setup SD card image with archlinux for Raspberry Pi

# Example usage:
- Use the example to create the config file
- Adjust the post-install script
- Execute sudo bash rpi-arch-sdprep.sh
- Connect with ssh to your Raspberry Pi, user: root, password: root
- Execute bash rpi-arch-sdprep-postinstall.sh

# Warning
This script will destroy all data on the configured block device.
Make sure that you know what you are doing.