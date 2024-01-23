#!/bin/bash
# Ubuntu Installation Script
# Author: Lucas Carvalho
# License: GPL v3

# Install required packages
sudo apt update
sudo apt -y install curl jq wget wipe

# List available disk devices
clear
sudo lsblk -I 8 -d
read -p "Enter the desired device (e.g., sda, sdb): " device

# Set up environment variables
export device
export jail="/media/$USER/mobile"

# Disk partitioning function
wipe() {
    clear
    read -p "This will erase the selected device. Do you want to proceed? (yes/no): " choice
    case $choice in
        yes)
            clear
            sudo umount -l $jail
            sudo rm -rf $jail
            sudo wipefs -a -f /dev/$device
            sudo partprobe -s /dev/$device
            sudo parted -s /dev/$device mklabel msdos
            sudo parted -s /dev/$device print free
            sudo parted -a optimal -s /dev/$device mkpart primary ext4 0% 512MB
            sudo parted -a optimal -s /dev/$device mkpart primary ext4 512MB 100%
            sudo parted -s /dev/$device print free
            sudo mkfs.vfat -n UEFI /dev/$device"1"
            sudo mkfs.xfs -f -L MOBILE /dev/$device"2"
            sudo partprobe -s /dev/$device
            sudo lsblk -I 8 -d
            ;;
        no)
            echo "Installation aborted."
            exit
            ;;
        *)
            echo "Invalid choice. Please enter 'yes' or 'no'."
            wipe
            ;;
    esac
}

# Run disk partitioning function
wipe

# Download Ubuntu Base
clear
echo "Downloading Ubuntu Base 20.04.3 LTS (Focal Fossa)..."
wget -c http://cdimage.ubuntu.com/ubuntu-base/releases/focal/release/ubuntu-base-20.04.3-base-amd64.tar.gz

# Create and mount media folder
clear
echo "Creating and mounting the folder for chroot..."
sudo mkdir -p $jail
sudo mount -t xfs --rw /dev/$device"2" $jail

# Extract Ubuntu Base
clear
echo "Extracting Ubuntu Base 20.04.3 LTS (Focal Fossa)..."
sudo tar -zxvf ubuntu-base-20.04.3-base-amd64.tar.gz -C $jail/

# Copy resolv.conf
sudo cp /etc/resolv.conf $jail/etc/

# Mount chroot
clear
echo "Mounting the $jail folder for chroot..."
for f in /sys /proc /dev; do sudo mount --rbind $f $jail/$f; done

# Create sources list
clear
echo "Creating sources file with Ubuntu repositories..."
sudo chmod 666 $jail/etc/apt/sources.list
echo "# Ubuntu
deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-proposed restricted main universe multiverse
# Security
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse
# Partner
deb http://archive.canonical.com/ubuntu focal partner" > $jail/etc/apt/sources.list
sudo chmod 644 $jail/etc/apt/sources.list

# Update and upgrade Ubuntu Base
clear
echo "Updating Ubuntu Base 20.04.3 LTS (Focal Fossa)..."
sudo chroot $jail apt update --fix-missing
sudo chroot $jail apt -y dist-upgrade

# Install base system
clear
echo "Installing base system for Ubuntu Base 20.04.3 LTS (Focal Fossa)..."
sudo chroot $jail apt -y install adb bash-completion btrfs-progs curl dphys-swapfile fdclone grub-efi-amd64 htop ifupdown ipset jq language-pack-pt linux-image-generic lvm2 mlocate nano ncdu network-manager net-tools nmap petname powerline resolvconf snap snapd screenfetch software-properties-common tar thin-provisioning-tools tldr tlp ubuntu-minimal unzip whois wget xfsprogs xz-utils --download-only
sudo chroot $jail apt -y install adb bash-completion btrfs-progs curl dphys-swapfile fdclone grub-efi-amd64 htop ifupdown ipset jq language-pack-pt linux-image-generic lvm2 mlocate nano ncdu network-manager net-tools nmap petname powerline resolvconf snap snapd screenfetch software-properties-common tar thin-provisioning-tools tldr tlp ubuntu-minimal unzip whois wget xfsprogs xz-utils

# Create user
clear
read -p "Enter your username: " username
sudo chroot $jail adduser $username
sudo chroot $jail addgroup $username adm
sudo chroot $jail addgroup $username sudo

# Customize GRUB
clear
sudo chmod 666 $jail/etc/default/grub
echo "# Old network interface names
GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"
# Uncomment to disable OS PROBE
GRUB_DISABLE_OS_PROBER=true" >> $jail/etc/default/grub
sudo chmod 644 $jail/etc/default/grub

# Configure fstab
clear
sudo chmod 666 $jail/etc/fstab
echo "proc          /proc proc     defaults     0     0
UUID=$(sudo blkid -p /dev/$device\"1\" -l -t LABEL=UEFI -s UUID -o value)     /boot/efi     vfat     umask=0077     0     1
UUID=$(sudo blkid -p /dev/$device\"2\" -l -t LABEL=MOBILE -s UUID -o value)     /     ext4     defaults,nodev,noatime,nodiratime     0     1" > $jail/etc/fstab
sudo chmod 644 $jail/etc/fstab
sudo chroot $jail mkdir -p /boot/efi
sudo chroot $jail mount -a

# Update GRUB
clear
sudo chroot $jail update-grub2
sudo chroot $jail update-initramfs -u
sudo chroot $jail grub-install --target=x86_64-efi --force /dev/$device

# Enable automatic disk integrity checking
clear
sudo touch $jail/etc/default/rcS
sudo chmod 666 $jail/etc/default/rcS
echo "FSCKFIX=yes" > $jail/etc/default/rcS
sudo chmod 644 $jail/etc/default/rcS
sudo touch $jail/boot/cmdline.txt
sudo chmod 666 $jail/boot/cmdline.txt
echo "fsck
