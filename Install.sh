#!/usr/bin/env bash
ping -c 1 example.com || { echo "Please connect to the internet and wait for the repo test to complete before running."; exit 1; }
lsblk
echo "Enter the drive you wish to install on."
