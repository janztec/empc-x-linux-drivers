#! /bin/sh

# Configure iX-Bus with the ixconfig program.
# Then load the modules that were requested by the ixconfig program.

# With the variable SOCKETCAN the used driver is selected
# SOCKETCAN="yes" the SocketCAN driver "janz_tec" and the neccessary modules are loaded
# SOCKETCAN="no"  the Janz Tec PCAN driver is loaded
#
SOCKETCAN="yes"

PATH="/sbin:/bin:/usr/sbin:/usr/bin"
IXCONFIG=/usr/janz/bin/ixconfig

KERNVER=`uname -r`
KERNVER_MAJ=`uname -r | sed -e 's/\([0-9]\.[0-9]\).*/\1/'`

# Loop over every line in output of ixconfig
echo "Configuring iX-Bus: "
($IXCONFIG; echo) | # make sure there is a LF at the end
while read module args
do
	case "$module" in
		\#*|"") 
			continue ;;
		"wait-for-file") 
			# wait with increasing time
			for ws in 010 010 020 040 080 160 320 640; do
				sleep 0.${ws}
				if [ -r $args ]; then
					break
				fi
			done
			continue ;;
		"wait") 
			sleep 0.0${args}
			continue;;
	esac

	if [ $module = "pcan" ]; then
		if [ $SOCKETCAN = "yes" ]; then
			(lsmod | grep jtec_can) >/dev/null
			if [ x$? = x0 ]; then
				echo "jtec_can - already loaded."
				continue
			fi
			# load socketcan modules and driver
			modprobe can
			modprobe can-dev
			#modprobe can-raw
			modprobe sja1000
			modprobe sja1000_platform
			modprobe jtec_can $args
			# Configure socketCAN: /etc/network/interfaces
				continue
		else
			echo -n "$module - "
			pattern=`echo $module | sed -e 's/[-_]/[-_]/g'`
			(lsmod | grep $pattern) >/dev/null
			if [ x$? = x0 ]; then
				echo "already loaded."
				continue
			fi

			IFS=","
			set $args
			K=$(($#-1))
			i=0
			while [ $i -lt $(($K/2)) ]
			do
				mknod /dev/pcan_$i c 58 $i
				i=`expr $i + 1`
			done
			chmod 666 /dev/pcan_?
			IFS=" "
		fi
	fi

	# load janz driver
	echo -n "$module - "

	pattern=`echo $module | sed -e 's/[-_]/[-_]/g'`
	(lsmod | grep $pattern) >/dev/null
	if [ x$? = x0 ]; then
		echo "already loaded."
		continue
	fi

	if [ -r "/lib/modules/$KERNVER/kernel/drivers/misc/$module.ko" ]; then
		insmod "/lib/modules/$KERNVER/kernel/drivers/misc/$module.ko" $args
	elif [ -r "/lib/modules/$KERNVER/$module.ko" ]; then
		insmod "/lib/modules/$KERNVER/$module.ko" $args
	elif [ -r "/lib/modules/$KERNVER/$module.o" ]; then
		insmod "/lib/modules/$KERNVER/$module.o" $args
	elif [ -r "/lib/modules/$KERNVER_MAJ/$module.ko" ]; then
		insmod "/lib/modules/$KERNVER_MAJ/$module.ko" $args
	elif [ -r "/lib/modules/$KERNVER_MAJ/$module.o" ]; then
		insmod "/lib/modules/$KERNVER_MAJ/$module.ko" $args
	else
		echo Module "$module.(k)o" not found
	fi

done