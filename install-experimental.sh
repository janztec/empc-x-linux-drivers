#!/bin/bash

export LC_ALL=C

ERR='\033[0;31m'
INFO='\033[0;32m'
NC='\033[0m' # No Color

KERNEL=$(uname -r)


clear
WELCOME="These drivers will be compiled and installed:\n
- CAN driver (SocketCAN)\n
These software components will be installed:\n
- ixconfig, ixbus, cmake, libtool, unzip, libsocketcan, can-utils\n
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

# get installed gcc version
GCCVERBACKUP=$(gcc --version | egrep -o '[0-9]+\.[0-9]+' | head -n 1)
# get gcc version of installed kernel
GCCVER=$(cat /proc/version | egrep -o 'gcc version [0-9]+\.[0-9]+' | egrep -o '[0-9.]+')


gcc --version | grep "$GCCVER" || (echo "$ERR Error: gcc $GCCVER not found! $NC"; exit 1);


rm -rf /tmp/empc-x-linux-drivers
mkdir -p /tmp/empc-x-linux-drivers
cd /tmp/empc-x-linux-drivers


# compile jtec_can driver
wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/jtec_can.zip -O jtec_can.zip
unzip jtec_can.zip
pushd jtec_can
make driver install

if [ ! -f "/lib/modules/$KERNEL/kernel/drivers/net/can/sja1000/jtec_can.ko" ]; then
 echo -e "$ERR Error: Installation failed! (driver module jtec_can build failed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (driver module jtec_can build failed)" 10 60
 exit 1
fi

popd

# compile i2c-ixssm driver
wget -nv https://github.com/janztec/empc-x-linux-drivers/raw/master/src/i2c-ixssm.zip -O i2c-ixssm.zip
unzip i2c-ixssm.zip
pushd i2c-ixssm
make driver install

if [ ! -f "/lib/modules/$KERNEL/kernel/drivers/misc/i2c-ixssm.ko" ]; then
 echo -e "$ERR Error: Installation failed! (driver module i2c-ixssm build failed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (driver module i2c-ixssm build failed)" 10 60
 exit 1
fi

popd

if ! cat /etc/modules | grep i2c_dev > /dev/null; then
    echo "" >> /etc/modules
    echo "i2c_dev" >> /etc/modules
fi

depmod -a

if ! cat /etc/default/grub | grep iomem=relaxed > /dev/null; then
    if ! cat /etc/default/grub | grep quiet  > /dev/null; then
        echo -e "$ERR Error: Installation failed! quiet entry in GRUB_CMDLINE_LINUX_DEFAULT not found! $NC" 1>&2
        whiptail --title "Error" --msgbox "Installation failed! quiet entry in GRUB_CMDLINE_LINUX_DEFAULT not found!" 10 60
    fi
    sed -i 's/quiet/quiet iomem=relaxed reboot=acpi/' /etc/default/grub
    update-grub
fi

# install ixconfig
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


# Install ixbus init service
wget -nv https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/src/ixbus -O /etc/init.d/ixbus
if [ ! -f "/etc/init.d/ixbus" ]; then
 echo -e "$ERR Error: Installation failed! (ixconfig not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (ixconfig not installed)" 10 60
 exit 1
fi

chmod 755 /etc/init.d/ixbus
update-rc.d ixbus defaults


wget -nv https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/scripts/empc-can-configbaudrate.sh -O /usr/bin/empc-can-configbaudrate.sh
if [ ! -f "/usr/bin/empc-can-configbaudrate.sh" ]; then
 echo -e "$ERR Error: Installation failed! (empc-can-configbaudrate not installed) $NC" 1>&2
 whiptail --title "Error" --msgbox "Installation failed! (empc-can-configbaudrate not installed)" 10 60
 exit 1
fi

chmod 755 /usr/bin/empc-can-configbaudrate.sh
bash /usr/bin/empc-can-configbaudrate.sh


if [ ! -f "/usr/local/bin/cansend" ]; then
 if (whiptail --title "emPC-A/RPI3 Installation Script" --yesno "Third party SocketCan library and utilities\n\n- libsocketcan-0.0.10\n- can-utils\n - candump\n - cansend\n - cangen\n\ninstall?" 16 60) then

    apt-get -y install git
    apt-get -y install cmake
    apt-get -y install libtool

    cd /usr/src/

    wget http://www.pengutronix.de/software/libsocketcan/download/libsocketcan-0.0.10.tar.bz2
    tar xvjf libsocketcan-0.0.10.tar.bz2
    rm -rf libsocketcan-0.0.10.tar.bz2
    cd libsocketcan-0.0.10
    ./configure && make && make install

    cd /usr/src/

    git clone https://github.com/linux-can/can-utils.git
    cd can-utils
    mkdir build
    cd build
    cmake .. && make install
        
 fi
fi




cd /



if (whiptail --title "emPC-X Installation Script" --yesno "Installation completed! reboot required\n\nreboot now?" 12 60) then

    reboot

fi
