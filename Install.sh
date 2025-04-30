#!/usr/bin/env bash -e

echo "This script is not finished please refrain from using it."
exit 1

# Zero out the variables the script will use.
drive=0
partition1=0
partition2=0
luks=0
lukspasswd=0
lukspart=0
tpm=0
vbox=0
sysop=0
non_sudo=0
firewall=0
hostname=0
locale_string=0

# Check for internet.
ping -c 1 example.com || { echo "Please connect to the internet and wait for the repo test to complete before running."; exit 1; }

# Ask for hostname.
echo -n "Hostname? "
read hostname
echo ""

# Ask for locale string.
echo -n "What is the locale? "
read locale_string

# Ask if it is in Virtualbox
echo -n "Is this machine running in Virtualbox? (y/N) "
read -n 1 vbox
echo ""
if [[ "$vbox" == "Y" ]]; then
  vbox="1"
elif [[ "$vbox" == "y" ]]; then
  vbox="1"
else
  vbox="0"
fi

# Prompt for host based firewall with default deny rule.
echo -n "Do you want nftables installed with a default deny in rule? (y/N) "
read -n 1 firewall
echo ""
if [[ "$firewall" == "Y" ]]; then
  firewall="1"
elif [[ "$firewall" == "y" ]]; then
  firewall="1"
else
  firewall="0"
fi

# Prompt user for the drive.
lsblk
echo -n "Enter the drive you wish to install on: "
read drive
echo ""

# Ask for encryption.
echo -n "Do you want an encrypted root? (y/N) "
read -n 1 luks
echo ""
if [[ "$luks" == "Y" ]]; then
  luks="1"
  echo -n "LUKS password: "
  read lukspasswd
  
  # Ask for tpm unlocking.
  echo -n "Do you want tpm unlocking (Requires TPM 2.0)? (y/N) "
  read -n 1 tpm
  echo ""
  if [[ "$tpm" == "Y" ]]; then
    tpm="1"
  elif [[ "$tpm" == "y" ]]; then
    tpm="1"
  else
    tpm="0"
  fi
elif [[ "$luks" == "y" ]]; then
  luks="1"
  echo -n "LUKS password: "
  read lukspasswd
  echo ""
  
  # Ask for TPM unlocking (again).
  echo -n "Do you want tpm unlocking (Requires TPM 2.0)? (y/N) "
  read -n 1 tpm
  echo ""
  if [[ "$tpm" == "Y" ]]; then
    tpm="1"
  elif [[ "$tpm" == "y" ]]; then
    tpm="1"
  else
    tpm="0"
  fi
else
  luks="0"
fi

# Handle if drive is an nvme or not and set partition varibles.
if [[ "$drive" == *"nvme"* ]]; then
  partition1="${drive}p1"
  partition2="${drive}p2"
else
  partition1="${drive}1"
  partition2="${drive}2"
fi

# Ask for account passwords.
echo -n "Password for sysop account (Admin): "
read sysop
echo ""
echo -n "Password for non_sudo account (non-admin): "
read non_sudo
echo ""

# Start partitioning
parted $drive --script 'mklabel gpt mkpart "EFI system partition" fat32 1MiB 1025MiB set 1 esp on mkpart "root" fat32 1025MiB 100% type 2 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709'

# Crypt setup, formating, drive mounting, swapfile.
if [[ "$luks" == "1" ]]; then
  echo $lukspasswd | cryptsetup -q luksFormat $partition2
  echo $lukspasswd | cryptsetup open $partition2 root
  lukspart="/dev/mapper/root"
  mkfs.ext4 $lukspart
  mount $lukspart /mnt
else
  mkfs.ext4 $partition2
  mount $partition2 /mnt
fi
mount --mkdir $partition1 /mnt/boot
mkswap -U clear --size 4G --file /mnt/swapfile
swapon /mnt/swapfile

# Add sublimetext repo
curl -O https://download.sublimetext.com/sublimehq-pub.gpg && sudo pacman-key --add sublimehq-pub.gpg && sudo pacman-key --lsign-key 8A8F901A && rm sublimehq-pub.gpg
echo -e "\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64" | sudo tee -a /etc/pacman.conf

# Resync with repos
pacman -Sy

# Start off the beggining of the file for the seccond stage within chroot.
echo "#!/usr/bin/env bash" > /mnt/stage2.sh
echo "drive=${drive}" >> /mnt/stage2.sh
echo "firewall=${firewall}" >> /mnt/stage2.sh
echo "partition1=${partition1}" >> /mnt/stage2.sh
echo "partition2=${partition2}" >> /mnt/stage2.sh
echo "luks=${luks}" >> /mnt/stage2.sh
echo "lukspasswd=${lukspasswd}" >> /mnt/stage2.sh
echo "lukspart=${lukspart}" >> /mnt/stage2.sh
echo "tpm=${tpm}" >> /mnt/stage2.sh
echo "vbox=${vbox}" >> /mnt/stage2.sh
echo "sysop=${sysop}" >> /mnt/stage2.sh
echo "non_sudo=${non_sudo}" >> /mnt/stage2.sh
echo "firewall=${firewall}" >> /mnt/stage2.sh
echo "hostname=${hostname}" >> /mnt/stage2.sh
echo "locale_string=${locale_string}" >> /mnt/stage2.sh
cat >> /mnt/stage2.sh << 'PLEASEGODENDTHISRECURSION'
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i "s/#${locale_string}/${locale_string}/" "/etc/locale.gen"
locale-gen
echo "LANG=${locale_string}" > /etc/locale.conf
echo "${hostname}" >> /etc/hostname
useradd -m sysop
useradd -m non_sudo
usermod -aG wheel sysop
echo "${sysop}" | passwd --stdin sysop
echo "${non_sudo}" | passwd --stdin non_sudo
systemctl enable NetworkManager.service
# Sudo stuff
echo '%wheel  ALL=(ALL:ALL) ALL' >> /etc/sudoers
# VM check based on previous inputs
if [[ $vbox == '1' ]]; then
  systemctl enable vboxservice.service
  echo "GSK_RENDERER=gl" >> /etc/environment
fi
# Grub install
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
# Build the final stage
echo "#!/usr/bin/env bash" > /home/sysop/finish_install.sh
echo "drive=${drive}" >> /home/sysop/finish_install.sh
echo "firewall=${firewall}" >> /home/sysop/finish_install.sh
echo "partition1=${partition1}" >> /home/sysop/finish_install.sh
echo "partition2=${partition2}" >> /home/sysop/finish_install.sh
echo "luks=${luks}" >> /home/sysop/finish_install.sh
echo "lukspasswd=${lukspasswd}" >> /home/sysop/finish_install.sh
echo "lukspart=${lukspart}" >> /home/sysop/finish_install.sh
echo "tpm=${tpm}" >> /home/sysop/finish_install.sh
echo "vbox=${vbox}" >> /home/sysop/finish_install.sh
echo "sysop=${sysop}" >> /home/sysop/finish_install.sh
echo "non_sudo=${non_sudo}" >> /home/sysop/finish_install.sh
echo "firewall=${firewall}" >> /home/sysop/finish_install.sh
echo "hostname=${hostname}" >> /home/sysop/finish_install.sh
echo "locale_string=${locale_string}" >> /home/sysop/finish_install.sh
cat >> /home/sysop/finish_install.sh << 'EOF'
if [[ $(whoami) == "root" ]]; then
  echo "Please refrain from running this script with sudo, the script will handle sudo on its own."
  exit 1
fi
ping -c 1 example.com || { echo "Please connect to the internet before running."; exit 1; }
sudo echo ""
mkdir ./from_source
cd ./from_source
git clone https://aur.archlinux.org/yay.git
cd ./yay
makepkg -si
yay -S web-greeter shikai-theme
EOF
chown sysop /home/sysop/finish_install.sh
chmod +x /home/sysop/finish_install.sh
PLEASEGODENDTHISRECURSION
chmod +x /mnt/stage2.sh

# Begin setup of the install list.
echo -n "" > ./install_list.txt
echo "base" >> ./install_list.txt
echo "linux-hardened" >> ./install_list.txt
echo "linux-firmware" >> ./install_list.txt
echo "gvim" >> ./install_list.txt
echo "grub" >> ./install_list.txt
echo "efibootmgr" >> ./install_list.txt
echo "lightdm" >> ./install_list.txt
echo "networkmanager" >> ./install_list.txt
echo "seahorse" >> ./install_list.txt
echo "gnome-keyring" >> ./install_list.txt
echo "nm-connection-editor" >> ./install_list.txt
echo "sublime-text" >> ./install_list.txt
echo "cinnamon" >> ./install_list.txt
echo "git" >> ./install_list.txt
echo "base-devel" >> ./install_list.txt
if [ "$vbox" == "1" ]; then
  echo "virtualbox-guest-utils" >> ./install_list.txt
fi
if [ "$tpm" == "1" ]; then
  echo "clevis" >> ./install_list.txt
fi
if [ "$firewall" == "1" ]; then
  echo "nftables" >> ./install_list.txt
fi
echo -n "sudo" >> ./install_list.txt
cat ./install_list.txt | tr '\n' ' ' > ./install_list.new.txt && rm ./install_list.txt && mv ./install_list.new.txt ./install_list.txt

# Begin install
pacstrap -K /mnt $(echo $(cat ./install_list.txt))
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ./stage2.sh
reboot
# Tack on during chroot for vm.
#echo "GSK_RENDERER=gl" >> /etc/environment
