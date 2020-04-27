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
# 2020-04-27 TC moOde 6.5.1
#

VER="v2.20"

# check environment
[[ $EUID -ne 0 ]] && { echo "*** You must be root to run the script! ***" ; exit 1 ; } ;

# Wait a bit to be sure rc.local is not starting too fast
waitForRc () {
	TIMESTAMP=$(date)
	echo "** "$TIMESTAMP
	sleep $1
}

cancelBuild () {
	if [ $# -gt 0 ] ; then
		echo "$1"
	fi
	echo "** Error: image build exited"
	echo "** Error: reboot to resume the build"
	apt-get clean
    # Power off Act LED
    echo 0 >/sys/class/leds/led0/brightness
    sleep 1
    # Now we are going reset to default control ACT LED
    echo mmc0 >/sys/class/leds/led0/trigger
    sleep 1
	exit 1
}

loadProperties () {
	local MOSBUILD_PROP=/home/pi/mosbuild/mosbuild.properties
	if [ -f $MOSBUILD_PROP ] ; then
		. $MOSBUILD_PROP
	else
		cancelBuild "** Error: unable to find properties file"
	fi
}

STEP_2 () {
	waitForRc 10
	cd $MOSBUILD_DIR
	timedatectl set-timezone "America/Detroit"

    if [ -z "$DIRECT" ] ; then
	  echo
	  echo "////////////////////////////////////////////////////////////////"
	  echo "//"
	  echo "// STEP 2 - Expand the root partition to 3.5GB"
	  echo "//"
	  echo "////////////////////////////////////////////////////////////////"
	  echo
    else
      echo "////////////////////////////////////////////////////////////////"
	  echo "//"
	  echo "// STEP 2 - Direct build so no need to expand Root partition"
	  echo "//"
	  echo "////////////////////////////////////////////////////////////////"
	  echo
      sed -i "s/raspberry.*//" /etc/hosts
    fi

	local MOODE_REL_ZIP=`echo $MOODE_REL | awk -F"/" '{ print $NF }'`

	echo "** Change password for user pi to moodeaudio"
	echo "pi:moodeaudio" | chpasswd
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: password change failed"
	fi

	echo "** Download moOde release"
	wget -q $MOODE_REL
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: download failed"
	fi
	echo "** Extract resizefs.sh"
	unzip -p -q $MOODE_REL_ZIP moode/www/command/resizefs.sh > ./resizefs.sh
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: unzip failed"
	fi
	echo "** Extract boot config.txt"
	unzip -p -q $MOODE_REL_ZIP moode/boot/config.txt.default > ./config.txt.default
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: unzip failed"
	fi

    if [ -z "$DIRECT" ] || [ `df -k --output=size / | tail -1` -lt 2500000 ] ; then
	  echo "** Expand SDCard to 3.5GB"
	  chmod 0755 ./resizefs.sh
	  sed -i "/PART_END=/c\PART_END=+3500M" ./resizefs.sh
	  ./resizefs.sh start
    fi

	echo "** Install boot/config.txt"
	cp ./config.txt.default /boot/config.txt

	echo "** Reboot 1"
	echo "3A" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_3A () {
	waitForRc 30
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 3A - Install core packages"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	local MOODE_REL_ZIP=`echo $MOODE_REL | awk -F"/" '{ print $NF }'`

	echo "** Unzip moOde release"
	unzip -o -q $MOODE_REL_ZIP
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: unzip failed"
	fi
	rm -f $MOODE_REL_ZIP

	echo "** Basic optimizations"
	dphys-swapfile swapoff
	dphys-swapfile uninstall
	systemctl disable dphys-swapfile
	systemctl disable cron.service
	systemctl enable rpcbind
	systemctl set-default multi-user.target
	systemctl stop apt-daily.timer
	systemctl disable apt-daily.timer
	systemctl mask apt-daily.timer
	systemctl stop apt-daily-upgrade.timer
	systemctl disable apt-daily-upgrade.timer
	systemctl mask apt-daily-upgrade.timer

	if [ -z "$http_proxy" ] ; then
		echo "** No proxy configured"
	else
		echo "** Configuring proxy for Internet access"
		echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/10proxy
        echo "Acquire::ForceIPv4 \"true\";" > /etc/apt/apt.conf.d/99force-ipv4
	fi

	echo "** Update Raspbian package list"
	#DEBIAN_FRONTEND=noninteractive apt-get update --allow-releaseinfo-change
	DEBIAN_FRONTEND=noninteractive apt-get update
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: update failed"
	fi

	echo "** Upgrading Raspbian installed packages to latest available"
	DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: upgrade failed"
	fi

	apt-get clean
	echo "** Reboot 2"
	echo "3B-4" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_3B_4 () {
	waitForRc 30
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 3B - Install core packages"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Refresh Raspbian package list"
	#DEBIAN_FRONTEND=noninteractive apt-get update --allow-releaseinfo-change
	DEBIAN_FRONTEND=noninteractive apt-get update
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: refresh failed"
	fi

	echo "** Install core packages"
	DEBIAN_FRONTEND=noninteractive apt-get -y install rpi-update php-fpm nginx sqlite3 php-sqlite3 php7.3-gd mpc \
		bs2b-ladspa libbs2b0 libasound2-plugin-equal telnet automake sysstat squashfs-tools shellinabox samba smbclient ntfs-3g \
		exfat-fuse git inotify-tools ffmpeg avahi-utils ninja-build python3-setuptools libmediainfo0v5 libmms0 libtinyxml2-6a \
		libzen0v5 libmediainfo-dev libzen-dev winbind libnss-winbind djmount haveged python3-pip xfsprogs triggerhappy
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo "** Install meson"
	cp ./moode/other/mpd/build-tools/meson-0.50.1.tar.gz ./
	tar xfz meson-0.50.1.tar.gz
	cd meson-0.50.1
	python3 setup.py install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	cd ..
	rm -rf meson-0.50.1*

	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo "** Install mediainfo"
	cp ./moode/other/mediainfo/mediainfo-18.12 /usr/local/bin/mediainfo
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install alsacap"
	cp ./moode/other/alsacap/alsacap /usr/local/bin
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install udisks-glue libs"
	DEBIAN_FRONTEND=noninteractive apt-get -y install libatasmart4 libdbus-glib-1-2 libgudev-1.0-0 \
		libsgutils2-2 libdevmapper-event1.02.1 libconfuse-dev libdbus-glib-1-dev
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install udisks-glue packages"
	dpkg -i ./moode/other/udisks-glue/liblvm2app2.2_2.02.168-2_armhf.deb
	dpkg -i ./moode/other/udisks-glue/udisks_1.0.5-1+b1_armhf.deb
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install udisks-glue pre-compiled binary"
	cp ./moode/other/udisks-glue/udisks-glue-1.3.5-70376b7 /usr/bin/udisks-glue

	echo "** Install udevil (includes devmon)"
	DEBIAN_FRONTEND=noninteractive apt-get -y install udevil
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Autoremove PHP 7.2"
	DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Autoremove PHP 7.2 failed"
	fi

	echo "** Systemd enable/disable"
	systemctl enable haveged
	systemctl disable shellinabox
	systemctl disable phpsessionclean.service
	systemctl disable phpsessionclean.timer
	systemctl disable udisks2
	systemctl disable triggerhappy

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 4 - Install enhanced networking"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo
	cd $MOSBUILD_DIR

	echo "** Install Host AP Mode packages"
	DEBIAN_FRONTEND=noninteractive apt-get -y install dnsmasq hostapd
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Disable hostapd and dnsmasq services"
	systemctl daemon-reload
	systemctl unmask hostapd
	systemctl disable hostapd
	systemctl disable dnsmasq

	echo "** Install Bluetooth packages"
	DEBIAN_FRONTEND=noninteractive apt-get -y install bluez-firmware pi-bluetooth \
		dh-autoreconf expect libdbus-1-dev libortp-dev libbluetooth-dev libasound2-dev \
		libusb-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev libsbc1 libsbc-dev

	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo "** Compile bluez"
	# Compile bluez 5.50
	# 2018-06-01 commit 8994b7f2bf817a7fea677ebe18f690a426088367
	cp ./moode/other/bluetooth/bluez-5.50.tar.xz ./
	tar xf bluez-5.50.tar.xz >/dev/null
	cd bluez-5.50
	autoreconf --install
	./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-library
	make
	make install
	cd ..
	rm -rf ./bluez-5.50*
	echo "** Delete symlink and bin for old bluetoothd"
	rm /usr/sbin/bluetoothd
	rm -rf /usr/lib/bluetooth
	echo "** Create symlink for new bluetoothd"
	ln -s /usr/libexec/bluetooth/bluetoothd /usr/sbin/bluetoothd

	echo "** Compile bluez-alsa"
	# Compile bluez-alsa 2.0.0
	# 2019-10-27 commit 4af3ebb361a66dc497accffa47301dfa1fd7b42f
	cp ./moode/other/bluetooth/bluez-alsa-master-2.0.0-4af3ebb.zip ./
	unzip -q bluez-alsa-master-2.0.0-4af3ebb.zip
	cd bluez-alsa-master
	echo "** NOTE: Ignore warnings from autoreconf and configure"
	autoreconf --install
	mkdir build
	cd build
	../configure --disable-hcitop --with-alsaplugindir=/usr/lib/arm-linux-gnueabihf/alsa-lib
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Configure failed"
	fi

	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi

	make install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make install failed"
	fi

	cd ../..
	rm -rf ./bluez-alsa-master*

	echo "** Check for default bluealsa.service file"
	if [ ! -f /lib/systemd/system/bluealsa.service ] ; then
		echo "** Creating default bluealsa.service file"
		echo "#" > /lib/systemd/system/bluealsa.service
		echo "# Created by Moode OS Builder" >> /lib/systemd/system/bluealsa.service
		echo "# The corresponfing file in /etc/systemd/system takes precidence" >> /lib/systemd/system/bluealsa.service
		echo "#" >> /lib/systemd/system/bluealsa.service
		echo "[Unit]" >> /lib/systemd/system/bluealsa.service
		echo "Description=BluezAlsa proxy" >> /lib/systemd/system/bluealsa.service
		echo "Requires=bluetooth.service" >> /lib/systemd/system/bluealsa.service
		echo "After=bluetooth.service" >> /lib/systemd/system/bluealsa.service
		echo >> /lib/systemd/system/bluealsa.service
		echo "[Service]" >> /lib/systemd/system/bluealsa.service
		echo "Type=simple" >> /lib/systemd/system/bluealsa.service
		echo "ExecStart=/usr/bin/bluealsa" >> /lib/systemd/system/bluealsa.service
		echo >> /lib/systemd/system/bluealsa.service
		echo "[Install]" >> /lib/systemd/system/bluealsa.service
		echo "WantedBy=multi-user.target" >> /lib/systemd/system/bluealsa.service
		echo >> /lib/systemd/system/bluealsa.service
	fi

	echo "** Disable bluetooth services"
	systemctl daemon-reload
	systemctl disable bluetooth.service
	systemctl disable bluealsa.service
	systemctl disable hciuart.service
	mkdir -p /var/run/bluealsa
	sync

	echo "** Cleanup"
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo "** Reboot 3"
	echo "5-6" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_5_6 () {
	waitForRc 10
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 5 - Install Rotary encoder driver"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Install WiringPi"
	# NOTE: Ignore warnings during build

	cp ./moode/other/wiringpi/wiringPi-2.50-36fb7f1.tar.gz ./
	tar xfz ./wiringPi-2.50-36fb7f1.tar.gz
	cd wiringPi-36fb7f1
	./build

	if [ $? -ne 0 ] ; then
		cancelBuild "** Install failed"
	fi

	cd ..
	rm -rf ./wiringPi*

	echo "** Compile C version of rotary encoder driver"
	cp ./moode/other/rotenc/rotenc.c ./
	gcc -std=c99 rotenc.c -orotenc -lwiringPi
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Compile failed"
	fi

	echo "** Install C version of driver"
	cp ./rotenc /usr/local/bin/rotenc_c
	rm ./rotenc*

	echo "** Install RPi.GPIO"
	pip3 install RPi.GPIO

	if [ $? -ne 0 ] ; then
		cancelBuild "** Install failed"
	fi

	echo "** Install musicpd"
	pip3 install python-musicpd

	if [ $? -ne 0 ] ; then
		cancelBuild "** Install failed"
	fi

	echo "** Install Python version of rotary encoder driver (default)"
	cp ./moode/other/rotenc/rotenc.py /usr/local/bin/rotenc

	if [ $? -ne 0 ] ; then
		cancelBuild "** Install failed"
	fi

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 6 - Install MPD"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Create MPD runtime environment"
	useradd mpd
	mkdir /var/lib/mpd
	mkdir /var/lib/mpd/music
	mkdir /var/lib/mpd/playlists
	touch /var/lib/mpd/state
	chown -R mpd:audio /var/lib/mpd
	mkdir /var/log/mpd
	touch /var/log/mpd/log
	chmod 644 /var/log/mpd/log
	chown -R mpd:audio /var/log/mpd
	cp ./moode/mpd/mpd.conf.default /etc/mpd.conf
	chown mpd:audio /etc/mpd.conf
	chmod 0666 /etc/mpd.conf
	echo "** Set permissions for D-Bus (for bluez-alsa)"
	usermod -a -G audio mpd

	echo "** Install MPD dev lib packages"
	DEBIAN_FRONTEND=noninteractive apt-get -y install \
	libyajl-dev \
	libasound2-dev \
	libavahi-client-dev \
	libavcodec-dev \
	libavformat-dev \
	libbz2-dev \
	libcdio-paranoia-dev \
	libcurl4-gnutls-dev \
	libfaad-dev \
	libflac-dev \
	libglib2.0-dev \
	libicu-dev \
	libid3tag0-dev \
	libiso9660-dev \
	libmad0-dev \
	libmpdclient-dev \
	libmpg123-dev \
	libmp3lame-dev \
	libshout3-dev \
	libsoxr-dev \
	libsystemd-dev \
	libvorbis-dev \
	libwavpack-dev \
	libwrap0-dev \
	libzzip-dev

	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Install Boost 1.68 dev libs"
	cp ./moode/other/boost/boost_1.68_headers.tar.gz /
	cp ./moode/other/boost/boost_1.68_libraries.tar.gz /
	cd /
	tar xfz ./boost_1.68_headers.tar.gz
	tar xfz ./boost_1.68_libraries.tar.gz
	rm ./boost_*.gz
	cd $MOSBUILD_DIR
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Install pre-compiled binary"
	cp ./moode/other/mpd/$MPD_BIN /usr/local/bin/mpd

	echo "** Cleanup"
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Autoremove failed"
	fi

	echo "** Reboot 4"
	echo "7-8" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_7_8 () {
	waitForRc 10
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 7 - Create moOde runtime environment"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Create directories"
	mkdir /var/local/www
	mkdir /var/local/www/commandw
	mkdir /var/local/www/imagesw
	mkdir /var/local/www/imagesw/toggle
	mkdir /var/local/www/db
	mkdir /var/local/php
	chmod -R 0755 /var/local/www
	mkdir /var/lib/mpd/music/RADIO

	echo "** Create mount points"
	mkdir /mnt/NAS
	mkdir /mnt/SDCARD
	mkdir /mnt/UPNP

	echo "** Create symlinks"
	ln -s /mnt/NAS /var/lib/mpd/music/NAS
	ln -s /mnt/SDCARD /var/lib/mpd/music/SDCARD
	ln -s /media /var/lib/mpd/music/USB

	echo "** Create logfiles"
	touch /var/log/moode.log
	chmod 0666 /var/log/moode.log
	touch /var/log/php_errors.log
	chmod 0666 /var/log/php_errors.log

	echo "** Create misc files"
	cp ./moode/mpd/sticker.sql /var/lib/mpd
	cp -r "./moode/other/sdcard/Stereo Test/" /var/lib/mpd/music/SDCARD/
	cp ./moode/network/interfaces.default /etc/network/interfaces
	cp ./moode/network/dhcpcd.conf.default /etc/dhcpcd.conf
	cp ./moode/network/hostapd.conf.default /etc/hostapd/hostapd.conf
	cp ./moode/var/local/www/db/moode-sqlite3.db.default /var/local/www/db/moode-sqlite3.db
	# if we are building over wifi, wpa_supplicant will already be configred
	# with ssid and pwd so we need to update cfg_network to match.
	if [ -z $SSID ] ; then
		cp ./moode/network/wpa_supplicant.conf.default /etc/wpa_supplicant/wpa_supplicant.conf
	else
		sqlite3 /var/local/www/db/moode-sqlite3.db "UPDATE cfg_network SET wlanssid='$SSID', wlanpwd='$PSK' WHERE id=2"
	fi

	echo "** Establish permissions"
	chmod 0777 /var/lib/mpd/music/RADIO
	chmod -R 0777 /var/local/www/db
	chown www-data:www-data /var/local/php

	echo "** Misc deletes"
	rm -r /var/www/html
	rm /etc/update-motd.d/10-uname

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 8 - Install moOde sources and configs"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Install application sources and configs"
	rm /var/lib/mpd/music/RADIO/* 2> /dev/null
	rm -rf /var/www/images/radio-logos/ 2> /dev/null
	cp ./moode/mpd/RADIO/* /var/lib/mpd/music/RADIO
	cp ./moode/mpd/playlists/* /var/lib/mpd/playlists
	cp -r ./moode/etc/* /etc
	cp -r ./moode/home/* /home/pi
	mv /home/pi/dircolors /home/pi/.dircolors
	mv /home/pi/xinitrc.default /home/pi/.xinitrc
	cp -r ./moode/lib/* /lib
	cp -r ./moode/usr/* /usr
	cp -r ./moode/var/* /var
	cp -r ./moode/www/* /var/www
	chmod 0755 /home/pi/*.sh
	#chmod 0755 /home/pi/*.php
	chmod 0755 /var/www/command/*
	sqlite3 /var/local/www/db/moode-sqlite3.db "CREATE TRIGGER ro_columns BEFORE UPDATE OF param, value, [action] ON cfg_hash FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'read only'); END;"
	sqlite3 /var/local/www/db/moode-sqlite3.db "UPDATE cfg_system SET value='Emerald' WHERE param='accent_color'"

	echo "** Establish permissions for service files"
	echo "** MPD"
	chmod 0755 /etc/init.d/mpd
	chmod 0644 /lib/systemd/system/mpd.service
	chmod 0644 /lib/systemd/system/mpd.socket
	echo "** Bluetooth"
	chmod 0666 /etc/bluealsaaplay.conf
	chmod 0644 /etc/systemd/system/bluealsa-aplay@.service
	chmod 0644 /etc/systemd/system/bluealsa.service
	chmod 0644 /lib/systemd/system/bluetooth.service
	chmod 0755 /usr/local/bin/a2dp-autoconnect
	echo "** Rotenc"
	chmod 0644 /lib/systemd/system/rotenc.service
	echo "** Udev"
	chmod 0644 /etc/udev/rules.d/*
	echo "Localui"
	chmod 0644 /lib/systemd/system/localui.service
	echo "SSH term server"
	sudo chmod 0644 /lib/systemd/system/shellinabox.service

	echo "** Services are started by moOde Worker so lets disable them here"
	systemctl daemon-reload
	systemctl disable mpd.service
	systemctl disable mpd.socket
	systemctl disable rotenc.service

	echo "** Binaries will not have been installed yet, but let's disable the services here"
	chmod 0644 /lib/systemd/system/squeezelite.service
	systemctl disable squeezelite
	chmod 0644 /lib/systemd/system/upmpdcli.service
	systemctl disable upmpdcli.service

	echo "** Reset permissions"
	chmod -R 0755 /var/www
	chmod -R 0755 /var/local/www
	chmod -R 0777 /var/local/www/db
	chmod -R ug-s /var/local/www
	chmod -R 0755 /usr/local/bin

	echo "** Initial permissions for certain files. These also get set during moOde Worker startup"
	chmod 0777 /var/local/www/playhistory.log
	chmod 0777 /var/local/www/currentsong.txt
	touch /var/local/www/libcache.json
	chmod 0777 /var/local/www/libcache.json

	echo "** Re-establish image build autorun in rc.local"
	sed -i "s/^exit.*//" /etc/rc.local
	echo "$MOSBUILD_DIR/mosbuild_worker.sh >> /home/pi/mosbuild.log 2>> /home/pi/mosbuild.log" >> /etc/rc.local
	echo "exit 0" >> /etc/rc.local

	echo "** Update sudoers file"
	cp /etc/sudoers /tmp/sudoers.bak
	chmod 0777 /tmp/sudoers.bak
	echo -e "pi\tALL=(ALL) NOPASSWD: ALL" >> /tmp/sudoers.bak
	echo -e "www-data\tALL=(ALL) NOPASSWD: ALL" >> /tmp/sudoers.bak
	visudo -cf /tmp/sudoers.bak
	if [ $? -eq 0 ]; then
		cp /tmp/sudoers.bak /etc/sudoers
	else
		cancelBuild "** Error: Update sudoers file failed"
	fi

	echo "** Reboot 5"
	echo "9-10" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_9_10 () {
	waitForRc 10
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 9 - Alsaequal"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Install alsaequal"
	amixer -D alsaequal > /dev/null

	echo "** Establish permissions"
	chmod 0755 /usr/local/bin/alsaequal.bin
	chown mpd:audio /usr/local/bin/alsaequal.bin
	#rm /usr/share/alsa/alsa.conf.d/equal.conf
	rm /etc/alsa/alsa.conf.d/equal.conf

	echo "** Wait 45 secs for moOde Startup to complete"
	sleep 45

	echo "** List MPD outputs"
	mpc outputs
	echo "** Enable only output 1"
	mpc enable only 1

	echo "** Alsaequal installed"

	if [ -z "$SQUASH_FS" ] ; then
		echo "** STEP 10 - Squashfs option not selected"
		STEP_11
	else
		echo
		echo "////////////////////////////////////////////////////////////////"
		echo "//"
		echo "// STEP 10 - Optionally squash /var/www"
		echo "//"
		echo "////////////////////////////////////////////////////////////////"
		echo

		echo "** Add squashfs mount to /etc/fstab"
		echo "/var/local/moode.sqsh   /var/www        squashfs        ro,defaults     0       0" >> /etc/fstab

		echo "** Squash /var/www"
		rm /var/local/moode.sqsh
		mksquashfs /var/www /var/local/moode.sqsh

		echo "** Remove contents of /var/www"
		rm -rf /var/www/*
	fi

	echo "** Reboot 6"
	echo "11" > $MOSBUILD_STEP
	sync
	reboot
}

STEP_11 () {
	waitForRc 30
	cd $MOSBUILD_DIR

	if [ -z "$LATEST_KERNEL" ] ; then
		echo "** STEP 11 - Updated kernel option not selected"
		STEP_12_13
	else
		echo
		echo "////////////////////////////////////////////////////////////////"
		echo "//"
		echo "// STEP 11 - Optionally, install updated Linux Kernel"
		echo "//"
		echo "////////////////////////////////////////////////////////////////"
		echo

		echo "** Download and install Linux kernel $KERNEL_VER build $KERNEL_BUILD"
		echo "y" | PRUNE_MODULES=1 rpi-update $KERNEL_HASH
		if [ $? -ne 0 ] ; then
			cancelBuild "** Error: rpi-update failed"
		else
			echo "** Cleanup"
		    rm -rf /lib/modules.bak
		    rm -rf /boot.bak
			DEBIAN_FRONTEND=noninteractive apt-get clean

			echo "** Install Edimax EW-7811Un fix"
			mv /etc/modprobe.d/blacklist-rtl8192cu.conf /etc/modprobe.d/blacklist-rtl8192cu.conf.delete

			echo "** Install drivers for Allo USBridge Signature"
			# WiFi driver (MrEngman stock)
			cp ./moode/other/allo/usbridge_sig/$KERNEL_VER-v7+/8812au.ko /lib/modules/$KERNEL_VER-v7+/kernel/drivers/net/wireless
			cp ./moode/other/allo/usbridge_sig/$KERNEL_VER-v7+/8812au.conf /etc/modprobe.d/
			chmod 0644 /lib/modules/$KERNEL_VER-v7+/kernel/drivers/net/wireless/8812au.ko
			chmod 0644 /etc/modprobe.d/*.conf
			# Eth/USB driver v2.0.0 (Allo enhanced)
			cp ./moode/other/allo/usbridge_sig/$KERNEL_VER-v7+/ax88179_178a.ko /lib/modules/$KERNEL_VER-v7+/kernel/drivers/net/usb

			echo "** Depmod"
			depmod $KERNEL_VER-v7+
			if [ $? -ne 0 ] ; then
				cancelBuild "** Error: depmod failed"
			fi

			echo "** Reboot 7"
			echo "12-13" > $MOSBUILD_STEP
			#echo "Fix for missing 4.19.y regulatory.db files"
			#sudo cp ./moode/other/firmware/regulatory.db* /lib/firmware
			sync
			reboot
		fi
	fi
}

STEP_12_13 () {
	waitForRc 10
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 12 - Launch and configure moOde!"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "1. Initial configuration"
	echo
	echo "a. http://moode"
	echo "b. Browse Tab, Default Playlist, Add"
	echo "c. Menu, Configure, Sources, UPDATE mpd database"
	echo "d. Menu, Audio, Mpd options, EDIT SETTINGS, APPLY"
	echo "e. Menu, System, Set timezone"
	echo "f. Clear system logs"
	echo "g. Compact sqlite database"
	echo "h. Keyboard"
	echo
	echo "2. Verification"
	echo
	echo "a) Playback tab"
	echo "b) Scroll to the last item which should be the Stereo Test track"
	echo "c) Click to begin play"
	echo "d) Menu, Audio info"
	echo "e) Verify Output stream is 16 bit 48 kHz"
	echo

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// STEP 13 - Final prep for image"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "1. Optionally check the boot partition."
	echo
	echo "NOTE: Run these commands one at a time."
	echo
	echo "If the message 'There are differences between boot sector and its backup' appears,"
	echo "enter 1 'Copy original to backup', then y to 'Perform changes ?'"
	echo
	echo "sudo umount /boot"
	echo "sudo dosfsck -tawl /dev/mmcblk0p1"
	echo "sudo dosfsck -r /dev/mmcblk0p1"
	echo "sudo dosfsck -V /dev/mmcblk0p1"
	echo "sudo mount /boot"
	echo

	echo "** Clear system logs"
	/var/www/command/util.sh clear-syslogs

	echo "** Remove DHCP lease files "
	rm /var/lib/dhcpcd5/*

	echo "** Reset network config to defaults "
	cp ./moode/network/interfaces.default /etc/network/interfaces
#	cp ./moode/network/wpa_supplicant.conf.default /etc/wpa_supplicant/wpa_supplicant.conf
	cp ./moode/network/dhcpcd.conf.default /etc/dhcpcd.conf
	cp ./moode/network/hostapd.conf.default /etc/hostapd/hostapd.conf

	if [ -z "$ADDL_COMPONENTS" ] ; then
		echo "** Additional components option not selected"
		finalCleanup
	else
		echo "** Reboot 8"
		echo "C1_C7" > $MOSBUILD_STEP
		echo "** Reboot"
		sync
		reboot
	fi
 }

COMP_C1_C7 () {
	waitForRc 30
	cd $MOSBUILD_DIR

	echo
	echo "################################################################"
	echo "#"
	echo "#"
	echo "# Install additional components"
	echo "#"
	echo "#"
	echo "################################################################"
	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 1 - MiniDLNA"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Install MiniDLNA package"
	DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install minidlna
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Disable MiniDLNA service"
	systemctl disable minidlna
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Disable failed"
	fi

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 2 - Auto-shuffle"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install pre-compiled binary"
	cp ./moode/other/ashuffle/ashuffle /usr/local/bin

	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 3 - MPD Audio Scrobbler"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Build MPDAS"
	git clone https://github.com/hrkfdn/mpdas
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Git clone failed"
	fi

	cd $MOSBUILD_DIR/mpdas
	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi

	echo "** Install binary"
	cp ./mpdas /usr/local/bin
	cd ..
	rm -rf ./mpdas

	echo "** Install conf file"
	cp ./moode/usr/local/etc/mpdasrc.default /usr/local/etc/mpdasrc
	chmod 0755 /usr/local/etc/mpdasrc

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 4A - Shairport-sync"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install shairport-sync devlibs"
	DEBIAN_FRONTEND=noninteractive apt-get -y install autoconf libtool libdaemon-dev libasound2-dev libpopt-dev libconfig-dev \
		avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev libmosquitto-dev
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install pre-compiled binary"
	cp ./moode/other/shairport-sync/$SPS_BIN /usr/local/bin/shairport-sync

	echo "** Install conf file"
	cd ..
	cp ./moode/etc/shairport-sync.conf /etc
	rm -rf ./shairport-sync

	echo "** Cleanup"
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 4B - Librespot"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install librespot devlibs"
	DEBIAN_FRONTEND=noninteractive apt-get -y install portaudio19-dev
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Install failed"
	fi

	echo "** Install pre-compiled binary"
	cp ./moode/other/librespot/$LR_BIN /usr/local/bin/librespot

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 5 - Squeezelite"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install pre-compiled binary"
	cp ./moode/other/squeezelite/$SL_BIN /usr/local/bin/squeezelite

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 6 - Upmpdcli"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install upmpdcli devlibs"
	DEBIAN_FRONTEND=noninteractive apt-get -y install libmicrohttpd-dev libexpat1-dev \
	libxml2-dev libxslt1-dev libjsoncpp-dev python-requests python-pip
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Compile Libupnp jfd5"
	cp ./moode/other/upmpdcli/libupnp-1.6.20.jfd5.tar.gz ./
	tar xfz ./libupnp-1.6.20.jfd5.tar.gz
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Un-tar failed"
	fi
	cd libupnp-1.6.20.jfd5
	./configure --prefix=/usr --sysconfdir=/etc
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Configure failed"
	fi
	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi
	make install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi
	echo "** Cleanup"
	cd ..
	rm -rf ./libupnp-1.6.20.jfd5
	rm libupnp-1.6.20.jfd5.tar.gz

	echo "** Compile Libupnpp"
	cp ./moode/other/upmpdcli/libupnpp-0.16.0.tar.gz ./
	tar xfz ./libupnpp-0.16.0.tar.gz
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Un-tar failed"
	fi
	cd libupnpp-0.16.0
	./configure --prefix=/usr --sysconfdir=/etc
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Configure failed"
	fi
	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi
	make install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi
	echo "** Cleanup"
	cd ..
	rm -rf ./libupnpp-0.16.0
	rm libupnpp-0.16.0.tar.gz

	echo "** Compile Upmpdcli"
	cp ./moode/other/upmpdcli/upmpdcli-code-1.2.16.tar.gz ./
	tar xfz ./upmpdcli-code-1.2.16.tar.gz
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Un-tar failed"
	fi
	cd upmpdcli-code
	./autogen.sh
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Autogen failed"
	fi
	./configure --prefix=/usr --sysconfdir=/etc
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Configure failed"
	fi
	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi
	make install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi
	echo "** Cleanup"
	cd ..
	rm -rf ./upmpdcli-code-1.2.16
	rm upmpdcli-code-1.2.16.tar.gz

	echo "** Configure runtime env"
	useradd upmpdcli
	cp ./moode/lib/systemd/system/upmpdcli.service /lib/systemd/system
	cp ./moode/etc/upmpdcli.conf /etc
	chmod 0644 /etc/upmpdcli.conf
	systemctl daemon-reload
	systemctl disable upmpdcli

	echo "** Compile Upexplorer"
	cp -r ./moode/other/libupnppsamples-code/ ./
	cd libupnppsamples-code
	./autogen.sh
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Autogen failed"
	fi
	./configure
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Configure failed"
	fi
	make
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Make failed"
	fi
	make install
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Cleanup"
	cd ..
	rm -rf ./libupnppsamples-code
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo "** Patch for upmpdcli gmusic plugin"
	cp ./moode/other/upmpdcli/session.py /usr/share/upmpdcli/cdplugins/gmusic

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 7 - Optionally install gmusicapi"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "This component enables access to Google Play Music service via UPnP renderer."
	echo "If its not installed, the Google Play section in UPnP config screen will not be present."
	echo "sudo pip install gmusicapi"

	echo "** Reboot 9"
	echo "C8_C9" > $MOSBUILD_STEP
	echo "** Reboot"
	sync
	reboot
}

COMP_C8_C9 () {
	waitForRc 30
	cd $MOSBUILD_DIR

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 8 - Local UI display"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Install Local UI packages"
	DEBIAN_FRONTEND=noninteractive apt-get -y install xinit xorg lsb-release xserver-xorg-legacy chromium-browser libgtk-3-0 libgles2
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: install failed"
	fi

	echo "** Permissions and service config"
	sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config
	systemctl daemon-reload
	systemctl disable localui

	echo "** Cleanup"
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi

	echo
	echo "Configure Chrome Browser"
	echo
	echo "NOTE: These steps are performed AFTER actually starting local display via System config,"
	echo "rebooting and then accessing moOde on the local display."
	echo
	echo "a. Connect a keyboard."
	echo "b. Press Ctrl-t to open a separate instance of Chrome Browser."
	echo "c. Enter url chrome://flags and scroll down to Overlay Scrollbars and enable the setting."
	echo "d. Optionally, enter url chrome://extensions and install the xontab virtual keyboard extension."

	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// COMPONENT 9 - Allo Piano 2.1 Firmware"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "Download and install firmware"
	wget https://github.com/allocom/piano-firmware/archive/master.zip
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Download failed"
	fi
	unzip -q master.zip
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Unzip failed"
	fi

	echo "Cleanup"
	cp -r ./piano-firmware-master/lib/firmware/allo /lib/firmware
	rm ./master.zip
	rm -rf ./piano-firmware-master

	finalCleanup
}

finalCleanup () {
	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "//"
	echo "// Final cleanup"
	echo "//"
	echo "////////////////////////////////////////////////////////////////"
	echo

	cd $MOSBUILD_DIR

	echo "** Install default rc.local"
	mv ./moode/etc/rc.local /etc/rc.local
	echo "** Remove mosbuild dir"
	cd ..
	rm -rf $MOSBUILD_DIR
	echo "** Clean package cache"
	DEBIAN_FRONTEND=noninteractive apt-get clean
	if [ $? -ne 0 ] ; then
		cancelBuild "** Error: Cleanup failed"
	fi
	echo "** Clear syslogs"
	/var/www/command/util.sh clear-syslogs

	echo "** Update MPD database"
	mpc update >/dev/null
	sleep 10

	TIMESTAMP=$(date)
	echo "** "$TIMESTAMP
	STOP_TIME=$(date +%s)
	INSTALLING_TIME=$(($STOP_TIME - $START_TIME))
	INSTALLING_TIME=$(date -u -d @$INSTALLING_TIME +"%T")
	TIMESTAMP=$(date)
	echo "** Installation time : $INSTALLING_TIME"
	echo
	echo "////////////////////////////////////////////////////////////////"
	echo "// END"
	echo "////////////////////////////////////////////////////////////////"
	echo

	echo "** Final reboot"
	reboot
}

##//////////////////////////////////////////////////////////////
##
## MAIN
##
##//////////////////////////////////////////////////////////////

#### Now we are going to control ACT LED
echo none > /sys/class/leds/led0/trigger
sleep 1
#### Power on Act LED
echo 1 > /sys/class/leds/led0/brightness
sleep 1

loadProperties

STEP=`cat $MOSBUILD_STEP`
case $STEP in
	2)
		STEP_2
		;;
	3A)
		STEP_3A
		;;
	3B-4)
		STEP_3B_4
		;;
	5-6)
		STEP_5_6
		;;
	7-8)
		STEP_7_8
		;;
	9-10)
		STEP_9_10
		;;
	11)
		STEP_11
		;;
	12-13)
		STEP_12_13
		;;
	C1_C7)
		COMP_C1_C7
		;;
	C8_C9)
		COMP_C8_C9
		;;
	*)
		echo "** Error: should never arrive at case = *"
		;;
esac

#### Power off Act LED
echo 0 > /sys/class/leds/led0/brightness
sleep 1
#### Now we are going reset to default control ACT LED
echo mmc0 >/sys/class/leds/led0/trigger
sleep 1

exit 0

##//////////////////////////////////////////////////////////////
## END
##//////////////////////////////////////////////////////////////
