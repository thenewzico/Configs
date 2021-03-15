# Archzfs install script - not intended for distribution

# set up archzfs repo for livecd
curl https://eoli3n.github.io/archzfs/init | bash

# partition for uefi and zfsroot on /dev/sda
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart esp 0% 512
parted -s /dev/sda mkpart archzfs 512 100%
parted -s /dev/sda et 1 esp on

# zfs setup
modprobe zfs

zpool create -f -o ashift=12
-O acltype=posixacl       \
-O relatime=on            \
-O xattr=sa               \
-O dnodesize=legacy       \
-O normalization=formD    \
-O mountpoint=none        \
-O canmount=off           \
-O devices=off            \
-R /mnt                   \
-O compression=lz4        \
-O encryption=aes-256-gcm \
-O keyformat=passphrase   \
-O keylocation=prompt     \
zroot /dev/disk/by-partlabel/archzfs 

zfs create -o mountpoint=none zroot/data
zfs create -o mountpoint=none zroot/ROOT
zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/default
zfs create -o mountpoint=/home zroot/data/home
zfs create -o mountpoint=/root zroot/data/home/root
zfs create -o mountpoint=/var -o canmount=off     zroot/var
zfs create                                        zroot/var/log
zfs create -o mountpoint=/var/lib -o canmount=off zroot/var/lib
zfs create                                        zroot/var/lib/libvirt
zfs create                                        zroot/var/lib/docker

# export and remount zpool
zpool export zroot
zpool import -d /dev/disk/by-partlabel -R /mnt zroot -N
zfs load-key zroot
zfs mount zroot/ROOT/default
zfs mount -a

zpool set bootfs=zroot/ROOT/default zroot
zpool set cachefile=/etc/zfs/zpool.cache zroot

# installation of archlinux

mkdir /mnt/boot
mkfs.vfat -F 32 /dev/sda1
mount /dev/sda1 /mnt/boot
pacstrap /mnt base base-devel linux linux-firmware iwd vim git

echo "/dev/sda1 /boot vfat defaults 0 0" >> /mnt/etc/fstab
mkdir /mnt/etc/zfs && cp /etc/zfs/zpool.cache /mnt/etc/zfs

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "archzfs-lap" > /mnt/etc/hostname
echo "127.0.0.1		localhost \n::1			localhost \n127.0.1.1 	archzfs-lap.localdomain archzfs-lap" >> /etc/hosts

# set up archzfs repo in installation
echo "[archzfs] \n Server = https://archzfs.com/$repo/$arch" >> /mnt/etc/pacman.conf
arch-chroot /mnt pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
arch-chroot /mnt pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
arch-chroot /mnt pacman -S --noconfirm zfs-linux

# install systemd-boot
arch-chroot /mnt bootctl install
echo "default    archlinux\ntimeout    5\neditor     no" >> /mnt/boot/loader/loader.conf
echo "title           Arch Linux\nlinux           vmlinuz-linux\ninitrd          initramfs-linux.img\noptions         zfs=zroot/ROOT/default rw" >> /mnt/boot/loader/entries/archlinux.conf

# mkinicpio tweaks
sed -i 's/^HOOKS.*/HOOKS="base udev autodetect modconf block keyboard zfs filesystems"/' /mnt/etc/mkinitcpio.conf

# install systemd targets and hostid
systemctl enable zfs.target --root=/mnt
systemctl enable zfs-import-cache --root=/mnt
systemctl enable zfs-mount --root=/mnt
systemctl enable zfs-import.target --root=/mnt
arch-chroot /mnt zgenhostid $(hostid)
arch-chroot /mnt mkinitcpio -p linux

# set root password
arch-chroot /mnt passwd

# unmount and export pool
umount /mnt/boot
zfs umount -a
zpool export zroot
