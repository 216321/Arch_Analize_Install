#!/usr/bin/env bash

# Check for internet
ping -c 1 example.com || { echo "Please connect to the internet and wait for the repo test to complete before running."; exit 1; }

# Add sublimetext repo
curl -O https://download.sublimetext.com/sublimehq-pub.gpg && sudo pacman-key --add sublimehq-pub.gpg && sudo pacman-key --lsign-key 8A8F901A && rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf

# Prompt user for the drive
lsblk
echo -n "Enter the drive you wish to install on: "
read drive

# Handle if drive is a nvme or not
if [[ "$drive" == *"nvme"* ]]; then
  partition1="${drive}p1"
  partition2="${drive}p2"
else
  partition1="${drive}1"
  partition2="${drive}2"
fi

# Start partitioning








####Tack on after chroot
echo "GSK_RENDERER=gl" >> /etc/environment
