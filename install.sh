#!/bin/bash

export LC_ALL=C

ERR='\033[0;31m'
INFO='\033[0;32m'
NC='\033[0m' # No Color

if [ $EUID -ne 0 ]; then
    echo "This script should be run as root."
    exit 1
fi

KERNEL=$(uname -r)


clear
WELCOME="These drivers will be compiled and installed:\n
- CAN driver (SocketCAN)\n
These software components will be installed:\n
- ixconfig, ixbus, autoconf, libtool, unzip, libsocketcan, can-utils\n
Important: create a backup copy of the system before installation!\n
continue installation?"

if (whiptail --title "emPC-X Installation Script" --yesno "$WELCOME" 20 60) then
    echo ""
else
    exit 0
fi

apt-get update -y
apt-get -y install bc build-essential unzip linux-headers-$(uname -r)


if [ ! -f "/lib/modules/$KERNEL/build" ]; then
 ln -s /usr/src/linux-headers-$KERNEL/ /lib/modules/$KERNEL/build
fi 


# get gcc version of installed kernel
GCCVER=$(cat /proc/version | egrep -o 'gcc version [0-9]+\.[0-9]+' | egrep -o '[0-9.]+')

gcc --version | grep "$GCCVER" || (echo "$ERR Error: gcc $GCCVER not found! $NC"; exit 1);


rm -rf /tmp/empc-x-linux-drivers
mkdir -p /tmp/empc-x-linux-drivers
cd /tmp/empc-x-linux-drivers


# Compile jtec_can driver
mkdir -p /tmp/jtec_can
wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/jtec_can.zip -O /tmp/jtec_can/jtec_can.zip
unzip /tmp/jtec_can/jtec_can.zip
pushd /tmp/jtec_can
make driver install

if [ ! -f "/lib/modules/$KERNEL/kernel/drivers/net/can/sja1000/jtec_can.ko" ]; then
 echo -e "$ERR Error: Installation failed! (driver module jtec_can build failed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (driver module jtec_can build failed)" 10 60
 exit 1
fi

popd


# Compile i2c-ixssm driver
mkdir -p /tmp/i2c-ixssm
wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/i2c-ixssm.zip -O /tmp/i2c-ixssm/i2c-ixssm.zip
unzip /tmp/i2c-ixssm/i2c-ixssm.zip
pushd /tmp/i2c-ixssm
make driver install

if [ ! -f "/lib/modules/$KERNEL/kernel/drivers/misc/i2c-ixssm.ko" ]; then
 echo -e "$ERR Error: Installation failed! (driver module i2c-ixssm build failed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (driver module i2c-ixssm build failed)" 10 60
 exit 1
fi

popd


# Add i2c_dev to /etc/modules if not already present
if ! cat /etc/modules | grep i2c_dev > /dev/null; then
    echo "" >> /etc/modules
    echo "i2c_dev" >> /etc/modules
fi

depmod -a

# Set required iomem=relaxed commandline parameter in grub config
if ! cat /etc/default/grub | grep iomem=relaxed > /dev/null; then
    if ! cat /etc/default/grub | grep quiet  > /dev/null; then
        echo -e "$ERR Error: Installation failed! quiet entry in GRUB_CMDLINE_LINUX_DEFAULT not found! $NC" 1>&2
        whiptail --title "Error" --msgbox "Installation failed! quiet entry in GRUB_CMDLINE_LINUX_DEFAULT not found!" 10 60
		exit 1
    fi
    sed -i 's/quiet/quiet iomem=relaxed reboot=acpi/' /etc/default/grub
    update-grub
fi

# Install ixconfig
mkdir -p /usr/janz/bin
ARCH=$(getconf LONG_BIT)
if [ $ARCH -eq 64 ]; then
 wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/ixconfig.64 -O /usr/janz/bin/ixconfig
else
 wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/ixconfig.32 -O /usr/janz/bin/ixconfig
fi

if [ ! -f "/usr/janz/bin/ixconfig" ]; then
 echo -e "$ERR Error: Installation failed! (ixconfig not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (ixconfig not installed)" 10 60
 exit 1
fi

chmod 755 /usr/janz/bin/ixconfig


# Install ixbus systemd service
wget -nv https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/src/ixbus.service -O /usr/lib/systemd/system/ixbus.service
if [ ! -f "/usr/lib/systemd/system/ixbus.service" ]; then
 echo -e "$ERR Error: Installation failed! (ixbus.service not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (ixbus.service not installed)" 10 60
 exit 1
fi
mkdir -p /opt/janztec/services
wget -nv https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/src/ixbus.sh -O /opt/janztec/services/ixbus.sh
if [ ! -f "/opt/janztec/services/ixbus.sh" ]; then
 echo -e "$ERR Error: Installation failed! (ixbus.sh not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (ixbus.sh not installed)" 10 60
 exit 1
fi

chmod 755 /opt/janztec/services/ixbus.sh
systemctl enable ixbus.service


# Install can baudrate configuration script
wget -nv https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/scripts/empc-can-configbaudrate.sh -O /usr/bin/empc-can-configbaudrate.sh
if [ ! -f "/usr/bin/empc-can-configbaudrate.sh" ]; then
 echo -e "$ERR Error: Installation failed! (empc-can-configbaudrate not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (empc-can-configbaudrate not installed)" 10 60
 exit 1
fi

chmod 755 /usr/bin/empc-can-configbaudrate.sh
bash /usr/bin/empc-can-configbaudrate.sh


# Install can-utils from apt repository
if ! dpkg-query -W -f='${db:Status-Status}' can-utils 2>/dev/null | grep -qx 'installed'; then
    if whiptail --title "emPC-X Installation Script" --yesno "can utils linux tools:\n - candump\n - cansend\n - cangen\n\ninstall?" 16 60; then
        apt-get -y install can-utils
    fi
fi


cd /
if (whiptail --title "emPC-X Installation Script" --yesno "Installation completed! reboot required\n\nreboot now?" 12 60) then
	reboot
fi
