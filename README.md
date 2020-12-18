# Moode OS Builder

The Moode OS Builder is a script that runs on a Raspberry Pi and automates the process of creating the custom Linux OS that runs moOde audio player. The Builder requires a Raspberry Pi running RaspiOS with SSH enabled, at least 2.5 GB free space on the boot SDCard, and an Internet connection, preferably via Ethernet

The OS can be built directly on the boot SDCard (direct build) or on a second USB-SDCard plugged into the Raspberry Pi. If the direct build method is used then the Pi must be running the exact release of RaspiOS Lite (Buster) specified in the Build requirements. The USB-SDCard method automatically uses the correct release of RaspiOS Lite (Buster).

A typical Build takes around 1 hour and during that time the Pi will automatically reboot many times as the build progresses through each of its sections.

@Koda59 © 2017

# Build requirements

If using the direct build method then boot a Raspberry Pi running [RaspiOS Buster Lite release 2020-12-02](http://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-12-04/2020-12-02-raspios-buster-armhf-lite.zip). No other release is guaranteed to work. If using a second USB-SDCard for the Build then make sure its not plugged into the Pi prior to starting the Build.

## Download the Builder script

Connect to the Pi via SSH and then run the commands listed below.
```
cd /home/pi
sudo wget -q http://moodeaudio.org/downloads/mos/mosbuild.sh -O /home/pi/mosbuild.sh
sudo chmod +x /home/pi/mosbuild.sh
```
## Start the Builder
```
sudo ./mosbuild.sh
```
Follow the instructions and prompts that will appear. The Build runs in two stages. The first stage prepares the SDCard with the files and configuration necessary for the second stage which is where the majority of the OS Build process takes place.

## After the first stage of the Build

When the first stage of the Build has completed one of two completion banners will be printed depending on which build method was choosen in the beginning. Follow the instructions in the completion banner to start the second stage of the Build.

### USB-SDCard method
```
** Base OS image created on second USB SDCard drive

Remove the USB SDCard drive and use the SDCard to boot a Pi.
The build will automatically continue at STEP 2 after boot.
It can take around 1 hour to complete.

Use cmds: mosbrief, moslog and moslast to monitor the process.

** Save base OS img for additional builds (y/n)?
```
### Direct build method
```
** Base OS image created on boot SDCard

Pi must be powered off then back on.
The build will automatically continue at STEP 2 after power on.
It can take around 1 hour to complete.

Use cmds: mosbrief, moslog and moslast to monitor the process.

** Power off the Pi (y/n)?
```
## During the second stage of the Build

A log file is maintained during the Build and can be monitored via SSH using the commands below. Use pi/moodeaudio as the userid/password for SSH login.
```
mosbrief  Prints only the section headers
moslog    Prints each line in real-time
moslast   Prints only the last few lines
```
Periodically monitor the build process for an error block in the build log that indicates the Build has exited (stopped) and can be resumed. In this case simply reboot the pi and the Build will resume at the beginning of the section that contained the error.
```
** Error: image build exited
** Error: reboot to resume the build
```
Sometimes when the source code reposiories are busy they will refuse connections. This is the most common cause of errors in the build process. The build may have to be resumed multiple times.

## Verifying a successful Build

The Build is successful when the last line of the Build log is:
```
// END
```
## Other Resources
moOde audio player: https://github.com/moode-player/moode<br>
moodeaudio.org: http://moodeaudio.org<br>
moOde Twitter feed: http://twitter.com/MoodeAudio<br>
