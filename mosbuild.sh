#!/bin/bash
#
# moOde OS Image Builder (C) 2017 Koda59
#
# This Program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This Program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# 2017-12-08 TC 	v1.0 adapted Koda59 original script
# 2017-12-17 Koda59 v1.1
# - fix USB Multi-Port Hub ( Extend test in getTargetUsb for multi devices to select device from parts )
# - fix Multi language in freespace test
# - fix possibly write test failed
# 2017-12-20 Koda59 v2.0 add method without USB SD Card reader (All from cuurent SD - fresh Raspbian)
# 2017-12-23 Koda59 v2.1 no changes on mosbuild.sh, only at mosbuild_worker.sh for powering on Act LED during build
# 2017-12-24 Koda59 v2.11
# - add total time to build to the mosbuild.log
# - add auto config SSID & PSK for the wifi if already configured
# - add aliase commands to monitor build process
# 2018-01-19 TC 	v2.2 simplified and adapted
# 2018-04-02 TC 	v2.4
# - sync with Build Recipe ver
# - add date entry prompt for direct build
# - use >> to fix echo "country=" > part1/wpa_supplicant.conf
# - update completion banners
# - chg wifi country from GB to US
# - create new etc/rc.local that unblocks wifi
# 2018-07-11 TC 	v2.5
# - sync with Build Recipe ver
# - bump to 2018-06-27 Stretch Lite
#
      
VER="v2.5"
DOWNLOAD_URL="http://moodeaudio.org/downloads/mos"

# check environment
[[ $EUID -ne 0 ]] && { echo "You must use sudo to run the OS Builder" ; exit 1 ; } ;

readYnInput () {
	while true; do
	    read -p "$1" YN
	    case $YN in
	        [y] ) break;;
	        [n] ) break;;
	        * ) echo "** Valid entries are y|n";;
	    esac
	done
}

readStrInput () {
    read -p "$1" STR
	readYnInput "** Make corrections (y/n)? "
	if [ $YN = "y" ] ; then
		readStrInput "$1"
	fi
}

cancelBuild () {
	if [ $# -gt 0 ] ; then
		echo "$1"
	fi
	echo "** OS build cancelled"
	ls mosbuild/*.img > /dev/null 2>&1
	# if no image files present remove the dir
	if [ $? -ne 0 ] ; then
		rm -rf ./mosbuild 2> /dev/null
	fi
    rm -f mosbuild.properties 2> /dev/null
	rm -f mosbuild_worker.sh 2> /dev/null
	rm -f mosbuild_befor_usb.txt 2> /dev/null
	rm -f mosbuild_after_usb.txt 2> /dev/null
	exit 1
}

mainBanner () {
	echo "****************************************************************"
	echo "**"
	echo "**  Moode OS Builder $VER"
	echo "**"
	echo "**  Welcome to the automated process for creating the wonderful"
	echo "**  custom Linux OS that runs moOde audio player."
	echo "**"
	echo "**  1. You will need a Raspberry Pi running Raspbian with SSH"
	echo "**  enabled and at least 2.5 GB free space on the boot SDCard."
	echo "**"
	echo "**  2. The build can be written directly to the boot SDCard or"
	echo "**  to a second USB-SDCard plugged into the Raspberry Pi."
	echo "**"
	echo "**  WARNING: Raspbian Stretch Lite 2018-06-27 must be used if"
	echo "**  building directly on the boot SDCard. It must be a fresh,"
	echo "**  unmodified installation of Stretch Lite otherwise the build"
	echo "**  results cannot be guaranteed."
	echo "**"
	echo "**  Be sure to backup the SDCard used to boot your Pi!"
	echo "**"
	echo "****************************************************************"
	echo
    readYnInput "** Write OS build directly to the boot SDCard (y/n)? "
	if [ $YN = "y" ] ; then
		DIRECT="y"
	fi
}

#
# direct build
#
directYBanner () {  
	echo  
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 1 - Writing OS directly to boot SDCard"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	readYnInput "** Do you have a backup of your boot SDCard (y/n)? "
	if [ $YN = "n" ] ; then
		cancelBuild
	fi

	readStrInput "** Enter current date (YYYY-MM-DD) "
	date --set $STR > /dev/null 2>&1
	if [ $? -ne 0 ] ; then
		echo "** Error: Invalid date format"
		readYnInput "** Reenter date (y/n)? "
		if [ $YN = "y" ] ; then
			readStrInput "** Enter current date (YYYY-MM-DD) "
		else
			cancelBuild
		fi
	fi
}

#
# non-direct build
#
directNBanner () {
	echo   
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 1 - Writing OS to second USB-SDCard"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

    testDiskSpace
	readYnInput "** Do you have a backup of your boot SDCard (y/n)? "
	if [ $YN = "n" ] ; then
		cancelBuild
	fi
	echo "** USB-SDCard device detection:"
	echo
	echo "   Accurately detecting the USB SDCard drive first requires"
	echo "   that all USB storage devices are unplugged from the Pi"
	echo
	readYnInput "** Are all USB storage devices unplugged (y/n)? "
	if [ $YN = "n" ] ; then
		cancelBuild
	fi
}

testDiskSpace () {
	echo "** Check free disk space"
    FREESPACE="$(df -k . --output=avail | tail -1)"
	if [ $FREESPACE -lt 2500000 ] ; then
		cancelBuild "** Error: Not enough free space on boot SDCard: 2.5GB required"
	else
		mkdir mosbuild 2> /dev/null
	fi
}

testUnzip () {
	if [ ! -f /usr/bin/unzip ] ; then
		echo "** Install Unzip utility"
		apt-get install unzip
		if [ $? -ne 0 ] ; then
			cancelBuild "** Error: Install failed"
		fi
	fi    
}

getTargetUsb () {
	ls -tr /dev/disk/by-id 2> /dev/null | sort > mosbuild_befor_usb.txt
	echo
	echo "   Now plug in the target USB SDCard drive"
	echo
	readYnInput "** Is target USB drive plugged in (y/n)? "
	if [ $YN = "n" ] ; then
		cancelBuild
	fi
	
	sleep 2
	ls -tr /dev/disk/by-id 2> /dev/null | sort > mosbuild_after_usb.txt
	DEVICE=`comm -13 mosbuild_befor_usb.txt mosbuild_after_usb.txt`	
	if [ -z "$DEVICE" ] ; then
		cancelBuild "** Error: Unable to find USB drive"
	fi

	# get device and partitions if any
	USBDEV=`comm -13 mosbuild_befor_usb.txt mosbuild_after_usb.txt | grep -v part`
	USBPART=`comm -13 mosbuild_befor_usb.txt mosbuild_after_usb.txt | grep part`
	rm -f mosbuild_befor_usb.txt mosbuild_after_usb.txt

	# identify each partition for umounting later
	if [ ! -z "$USBPART" ] ; then
		cd /dev/disk/by-id
		DEVPARTS=""
		for i in $USBPART ; do
			PARTDEV=`readlink -f $i`
			DEVPARTS="${DEVPARTS}${PARTDEV} "
		done
		cd - > /dev/null 2>&1
	fi

	if [ -z "$USBDEV" ] || [ `echo "$USBDEV" | wc -w` -gt 1 ] ; then
		# its odd to have no device so lets try to derive it from a partition
		USBDEV=`echo $DEVPARTS | awk -F" " '{print $1}' | head -c -2`
	else
		USBDEV=`cd /dev/disk/by-id ; readlink -f $USBDEV ; cd - > /dev/null 2>&1`
	fi

	echo "** USB drive detected on $USBDEV"
	# unmount partitions if any exist on the dev and are already mounted
	if [ ! -z "$USBPART" ] ; then
		for PART in $DEVPARTS ; do
			TRIES=0
			findmnt $PART > /dev/null
			if [ $? -eq 0 ] ; then
				umount $PART > /dev/null 2>&1
				while [ $? -ne 0 ] && [ $TRIES -lt 3 ] ; do
					let TRIES++
					echo "** Partition $PART cannot be unmounted, try $TRIES-3"
					sleep 5
					umount -l $PART > /dev/null 2>&1
				done
			fi
		done

		if [ $? -ne 0 ] ; then
			cancelBuild
		else
			echo "** Partitions unmounted on $USBDEV"
		fi
	fi
}

getOptions () {
	echo "** Options configuration:"
	echo
	echo "   There are only two build options that can be configured. The"
	echo "   1st is Proxy Server. Set it to 'n' unless you are certain that"
	echo "   your network requires proxied access to the Internet. The 2nd"
	echo "   is WiFi connection. For maximum speed and reliability set this"
	echo "   to 'n' and use an Ethernet connection for the Build."
	echo
	NUMOPT=2
	IDXOPT=1
	proxyServer
	useWireless
	#squashFs
	#updatedKernel
	#addlComponents

	# if the var does not exist then = n
	#SQUASH_FS=y
	LATEST_KERNEL=y
	ADDL_COMPONENTS=y
}
    
confirmBuild () {
	echo "** Configuration complete:"
	echo
	echo "The Builder has completed the configuration and is now ready"
	echo "to proceed with building Moode OS."
	echo
	readYnInput "** Proceed with build (y/n)? "
	if [ $YN = "n" ] ; then
		cancelBuild
	fi
}

##//////////////////////////////////////////////////////////////
## BEGIN OPTIONS
##//////////////////////////////////////////////////////////////
proxyServer () {
	readYnInput "** Option $((IDXOPT++))-$NUMOPT: use a proxy server for Internet access (y/n)? "
	if [ $YN = "y" ] ; then
		echo "** Enter proxy url in the format http://[[username]:[password]@]<proxy address>:<proxy port>/"
		readStrInput "** Proxy url: "
		HTTP_PROXY="$STR"
		HTTPS_PROXY="$STR"
	fi
}
isConnected () {
	# ping gateway address if one exists
	ping -q -w 1 -c 1 `ip r | grep default | cut -d ' ' -f 3` > /dev/null 2> /dev/null && return 0 || return 1
}
configWireless() {
	readStrInput "** SSID: "
	SSID="$STR"
	readStrInput "** Password: "
	PSK="$STR"
}
useWireless () {
	readYnInput "** Option $((IDXOPT++))-$NUMOPT: use a WiFi connection instead of Ethernet (y/n)? "
	if [ $YN = "y" ] ; then
		if isConnected && [ -f /etc/wpa_supplicant/wpa_supplicant.conf ] ; then
			SSID=`awk '(/^/||/ /) && /ssid=\"/' /etc/wpa_supplicant/wpa_supplicant.conf | sed -e 's/^[ \t]*//;s/ssid=\"\(.*\)\"/\1/'`
			PSK=`awk '(/^/||/ /) && /psk=\"/' /etc/wpa_supplicant/wpa_supplicant.conf | sed -e 's/^[ \t]*//;s/psk=\"\(.*\)\"/\1/'`
			echo "** You are already connected via WiFi with these settings:"
			echo "** SSID: $SSID"
			echo "** Password : $PSK"
			readYnInput "** Use these settings (y/n)? "
			if [ $YN = "n" ] ; then
				configWireless
			fi
		else
			configWireless
		fi
	fi
}
squashFs () {
	readYnInput "** Option $((IDXOPT++))-$NUMOPT: configure /var/www as squashfs (y/n)? "
	if [ $YN = "y" ] ; then
		SQUASH_FS=$YN
	fi
}
updatedKernel () {
	readYnInput "** Option $((IDXOPT++))-$NUMOPT: install updated Linux Kernel (y/n)? "
	if [ $YN = "y" ] ; then
		LATEST_KERNEL=$YN
	fi
}
addlComponents () {
	echo "** Option $((IDXOPT++))-$NUMOPT: Airplay, Ashuffle, LocalUI, Scrobbler, Squeezelite and UPnP/DLNA"
	readYnInput "** Install additional components (y/n)? "
	if [ $YN = "y" ] ; then
		ADDL_COMPONENTS=$YN
	fi
}
##//////////////////////////////////////////////////////////////
## END OPTIONS
##//////////////////////////////////////////////////////////////

testInternet () {
	echo "** Test Internet connection"
	if [ ! -z "$HTTP_PROXY" ] ; then 
		export http_proxy=$HTTP_PROXY
	fi
	wget -q http://www.google.com
	if [ $? -eq 0 ] ; then
		rm -f index.html
	else
		if [ ! -z "$HTTP_PROXY" ] ; then 
			echo "** Proxy url: $HTTP_PROXY"
		fi
		cancelBuild "** Error: Unable to detect Internet connection"
	fi
}

dnldHelpers () {  	
	echo "** Download helper files"
	wget -q $DOWNLOAD_URL/mosbuild.properties -O mosbuild.properties
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Unable to download Properties file"
	else 
		wget -q $DOWNLOAD_URL/mosbuild_worker.sh -O mosbuild_worker.sh
		if [ $? -ne 0 ] ; then
			cancelBuild "** Error: Unable to download Worker file"
		fi 
	fi
}

updProperties () {
	echo "** Add options to properties file"
	echo "START_TIME=$(date +%s)" >> mosbuild.properties
	
	if [ ! -z "$HTTP_PROXY" ] ; then
		echo "export http_proxy=$HTTP_PROXY" >> mosbuild.properties
		echo "export https_proxy=$HTTPS_PROXY" >> mosbuild.properties
	fi
	if [ ! -z "$SSID" ] ; then
		echo "SSID=\"$SSID\"" >> mosbuild.properties
		echo "PSK=\"$PSK\"" >> mosbuild.properties
	fi
	if [ ! -z "$SQUASH_FS" ] ; then
		echo "SQUASH_FS=$SQUASH_FS" >> mosbuild.properties
	fi
	if [ ! -z "$LATEST_KERNEL" ] ; then
		echo "LATEST_KERNEL=$LATEST_KERNEL" >> mosbuild.properties
	fi
	if [ ! -z "$ADDL_COMPONENTS" ] ; then
		echo "ADDL_COMPONENTS=$ADDL_COMPONENTS" >> mosbuild.properties
	fi
    if [ ! -z "$DIRECT" ] ; then
        echo "DIRECT=$DIRECT" >> mosbuild.properties
    fi
}
loadEnv () {
	echo "** Load properties into env"
	local MOSBUILD_PROP=mosbuild.properties
	if [ -f $MOSBUILD_PROP ] ; then
		. $MOSBUILD_PROP
	else
		cancelBuild "** Error: Unable to find properties file"
	fi
}

dnldRaspbian () {
	local RASPBIAN_ZIP=`echo $RASPBIAN_DNLD | awk -F"/" '{ print $NF }'`
	echo "** Download Rasbian Stretch Lite $RASPBIAN_ZIP"  
	cd mosbuild
	wget -q --show-progress $RASPBIAN_DNLD -O $RASPBIAN_ZIP
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Download failed"
	fi
	cd ..
}

unzipRaspbian () {
	local RASPBIAN_ZIP=`echo $RASPBIAN_DNLD | awk -F"/" '{ print $NF }'`
	
	echo "** Unzip $RASPBIAN_ZIP"
	cd mosbuild
	unzip -o $RASPBIAN_ZIP
	if [ $? -ne 0 ] ; then
		rm -f $RASPBIAN_ZIP
		cancelBuild "** Error: Unzip failed"
	else 
		rm -f $RASPBIAN_ZIP
	fi
	cd ..
}

mountImage () {
	echo "** Mount Raspbian partitions"
	mkdir part1
	mkdir part2
	LOOPDEV=$(sudo losetup -f)
	losetup -P $LOOPDEV mosbuild/$RASPBIAN_IMG
	
	mount -t vfat "$LOOPDEV"p1 part1
	if [ $? -ne 0 ] ; then
		rmdir part1
		rmdir part2
		cancelBuild "** Error: Mount failed for partition 1"
	fi

	mount -t ext4 "$LOOPDEV"p2 part2
	if [ $? -ne 0 ] ; then
		umount part1
		rmdir part1
		rmdir part2
		cancelBuild "** Error: Mount failed for partition 2"
	fi
}

modifyImage () {
	echo "** Modify partitions"

	if [ -z "$DIRECT" ] ; then
		touch part1/ssh
		echo "** Enable SSH"
	else
		# symlnk these so same code can be used
		ln -s /boot /home/pi/part1
		ln -s / /home/pi/part2
	fi

	if [ ! -z "$SSID" ] ; then
		echo "#########################################" > part1/wpa_supplicant.conf
		echo "# This file is automatically generated by" >> part1/wpa_supplicant.conf
		echo "# the player Network configuration page." >> part1/wpa_supplicant.conf
		echo "#########################################" >> part1/wpa_supplicant.conf
		echo >> part1/wpa_supplicant.conf
		echo "country=US" >> part1/wpa_supplicant.conf
		echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >> part1/wpa_supplicant.conf
		echo "update_config=1" >> part1/wpa_supplicant.conf
		echo >> part1/wpa_supplicant.conf
		echo "network={" >> part1/wpa_supplicant.conf
		echo "ssid=\"$SSID\"" >> part1/wpa_supplicant.conf
		echo "scan_ssid=1" >> part1/wpa_supplicant.conf
		echo "psk=\"$PSK\"" >> part1/wpa_supplicant.conf
		echo "}" >> part1/wpa_supplicant.conf
	fi

	sed -i "s/init=.*//" part1/cmdline.txt
	sed -i "s/quiet.*//" part1/cmdline.txt
	rm part2/etc/init.d/resize2fs_once 2> /dev/null
	rm part2/etc/rc3.d/S01resize2fs_once 2> /dev/null
	echo "** Remove auto-resize task"

	sed -i "s/^/net.ifnames=0 /" part1/cmdline.txt
	echo "** Enable familiar network interface names"

	mkdir part2$MOSBUILD_DIR
	cp -f mosbuild.properties part2$MOSBUILD_DIR
	cp -f mosbuild_worker.sh part2$MOSBUILD_DIR
	echo "2" >> part2$MOSBUILD_STEP
	chmod +x part2$MOSBUILD_DIR/mosbuild_worker.sh
	chown -R 1000.1000 part2$MOSBUILD_DIR
	echo "** Install main worker script"

	# modify rc.local
	sed -i "s/^exit.*//" part2/etc/rc.local
	# stretch requires unblocking wifi
	echo "if [ -f /run/wifi-country-unset ] ; then" >> part2/etc/rc.local
	echo "/usr/sbin/rfkill unblock wifi" >> part2/etc/rc.local
	echo "fi" >> part2/etc/rc.local
	echo "** Enable wifi unblock"
	echo "$MOSBUILD_DIR/mosbuild_worker.sh >> /home/pi/mosbuild.log 2>> /home/pi/mosbuild.log" >> part2/etc/rc.local
	echo "exit 0" >> part2/etc/rc.local
	echo "** Enable script for autorun after reboot"

	sed -i "s/raspberrypi/moode/" part2/etc/hostname
	sed -i "s/raspberrypi/moode/" part2/etc/hosts
	cp /etc/fake-hwclock.data part2/etc/ 2> /dev/null
	echo "** Change host name to moode"
    
    echo "alias moslog=\"tail -f ~/mosbuild.log\"" >> part2$MOSBUILD_DIR/../.bash_aliases
    echo "alias mosbrief=\"cat ~/mosbuild.log | grep 'COMPONENT\|STEP\|Compile \| END\|Error'\"" >> part2$MOSBUILD_DIR/../.bash_aliases
    echo "alias moslast=\"tail -25 ~/mosbuild.log\"" >> part2$MOSBUILD_DIR/../.bash_aliases
    chown 1000.1000 part2$MOSBUILD_DIR/../.bash_aliases
    echo "** Add alias commands for monitoring the build"

	# remove symlinks if indicated
	if [ -v DIRECT ] ; then
		rm part1
		rm part2
	fi
    
	echo "** Flush cached disk writes"
	sync
}

umountImage () {
	echo "** Partitions unmounted"
	losetup -D
	umount part1
	umount part2
	rmdir part1
	rmdir part2 
}

writeImage () { 
	echo "** Write OS image to USB-SDCard drive on $USBDEV"
	dd if=mosbuild/$RASPBIAN_IMG of=$USBDEV
	if [ $? -eq 0 ] ; then
    	echo "** Flush cached disk writes"
	    sync
		echo "****************************************************************"
		echo "**"
		echo "** Base OS created on second USB SDCard drive"
		echo "**"
		echo "** Remove the USB SDCard drive and use the SDCard to boot a Pi."
		echo "** The build will automatically continue at STEP 2 after boot."
		echo "** It can take around 1 hour to complete."
		echo "**"
		echo "** The cmds mosbrief, moslog and moslast can be used to monitor"
		echo "** the build via SSH. Connect to server moode, user pi, and"
		echo "** password moodeaudio for SSH login."
		echo "**"
		echo "****************************************************************"
		echo
		readYnInput "** Save base OS image for additional builds (y/n)? "
		if [ $YN = "n" ] ; then
			rm -rf mosbuild* 2> /dev/null
		else
			echo
			echo "** NOTE: The saved image will become out of date when newer"
			echo "** versions of mosbuild or moOde audio player are released."
			echo
		fi
	else
		cancelBuild "** Error: Image write failed"
	fi
}

cleanUp () {
	rm -f mosbuild.properties 2> /dev/null
	rm -f mosbuild_worker.sh 2> /dev/null
	rm -f mosbuild_befor_usb.txt
	rm -f mosbuild_after_usb.txt

	if [ -z "$DIRECT" ] ; then 
		return
	else
		echo "****************************************************************"
		echo "**"
		echo "** Base OS created on boot SDCard"
		echo "**"
		echo "** The Pi must be powered off then back on."
		echo "** The build will automatically continue at STEP 2 after power on."
		echo "** It can take around 1 hour to complete."
		echo "**"
		echo "** The cmds mosbrief, moslog and moslast can be used to monitor"
		echo "** the build via SSH. Connect to server moode, user pi, and"
		echo "** password moodeaudio for SSH login."
		echo "**"
		echo "****************************************************************"
		echo
		readYnInput "** Power off the Pi (y/n)? "
		if [ $YN = "y" ] ; then
			poweroff
		fi
	fi
}

##//////////////////////////////////////////////////////////////
##
## MAIN
##
##//////////////////////////////////////////////////////////////

mainBanner
if [ -z "$DIRECT" ] ; then 
	directNBanner
	testUnzip
	getTargetUsb
else
	directYBanner
fi
getOptions
confirmBuild
testInternet
dnldHelpers
updProperties
loadEnv
if [ -z "$DIRECT" ] ; then
	# check if img already exist
	if [ -f mosbuild/$RASPBIAN_IMG ] ; then
		echo "** Base OS image was saved from previous build"
		readYnInput "** Use saved image to write to USB drive (y/n)? "
		if [ $YN = "y" ] ; then
			writeImage
			cleanUp
			exit 0
		fi
	fi
	dnldRaspbian
	unzipRaspbian
	mountImage
	modifyImage
	umountImage
	writeImage
else 
	modifyImage
fi
cleanUp
exit 0

##//////////////////////////////////////////////////////////////
## END
##//////////////////////////////////////////////////////////////
