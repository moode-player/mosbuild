# Why do I need to build moOde OS myself?

moOde depends on a number of software packages which are licensed in various ways. Due to the amount of effort involved for each release in manually resolving compliance request from those software vendors, having each of us build our own moOde is the most straight-forward way to stay true to all the licensing requirements. The moOde OS Builder is a script that runs on a Raspberry Pi and automates the process of creating the custom Linux OS that runs moOde audio player. 

moOde OS Builder created by @Koda59 © 2017

# Build requirements

The Builder requires:

- a Raspberry Pi running Raspbian, with SSH enabled, 
- at least 2.5 GB free space on the boot SDCard, and 
- an Internect connection, preferably via Ethernet. 

# Build steps

The process to build moOde can be summarised in 2 steps: 

1. Install moOde OS main packages
2. Configure moOde OS packages

Optionally, a previous step consisting in burning Raspbian OS in a SDCard. See [Raspbian Installation](raspbian-installation.md) document for details, if needed.

## Important notes

A typical Build takes around 1 hour and during that time the RPi will automatically reboot many times as the build progresses through each of its sections. Login password will change from `pi` into `moodeaudio` when entering step 2. 

The OS can be built directly on the boot SDCard or on a second USB-SDCard plugged into the Raspberry Pi. In any case, be sure to backup the SDCard used to boot your RPi, all previous data will be lost!


## Step 1: Install moOde OS main packages

### Download the Builder script

To download the builder run the commands below:

```
cd /home/pi
sudo wget -q http://moodeaudio.org/downloads/mos/mosbuild.sh -O /home/pi/mosbuild.sh
sudo chmod +x /home/pi/mosbuild.sh
```

### Start the Builder

There are two types of build: direct in the Raspbian SDCard, or using a second card, in the USB port.  If using a second USB-SDCard for the Build, make sure it's not plugged into the RPi prior to starting the Build.

To start installation run the command below:

```
sudo ./mosbuild.sh
```

Follow the instructions and prompts that will appear. The Build runs in two stages. The first stage installs moOde OS main packages. Final stage is where the majority of the OS Build process takes place, properly configuring installed packages.

When the first stage of the Build has completed one of two completion banners will be printed depending on which build method was chosen in the beginning. Follow the instructions in the completion banner to start the second stage of the Build.


#### Direct build method

```
** Base OS image created on boot SDCard

Pi must be powered off then back on.
The build will automatically continue at STEP 2 after power on.
It can take around 1 hour to complete.

Use cmds: mosbrief, moslog and moslast to monitor the process.

** Power off the Pi (y/n)? 
```

#### USB-SDCard build method

The USB-SDCard method automatically uses the correct release of Raspbian Stretch Lite. 

```
** Base OS image created on second USB SDCard drive

Remove the USB SDCard drive and use the SDCard to boot a Pi.
The build will automatically continue at STEP 2 after boot.
It can take around 1 hour to complete.

Use cmds: mosbrief, moslog and moslast to monitor the process.

** Save base OS img for additional builds (y/n)? 
```

## Step 2: Configure moOde OS packages

The process will run automatically since all options have been determined in the previous questions. Remember to use pi/moodeaudio as the userid/password for SSH login once the process has entered this second stage.

A log file is maintained during the Build and can be monitored via SSH using the single word commands below:

```
mosbrief  (Prints only the section headers)
moslog    (Prints each line in real-time)
moslast   (Prints only the last few lines)
```

Periodically monitor the build process for an error block in the build log that indicates the Build has exited (stopped) and can be resumed. In this case simply reboot the RPi and the Build will resume at the beginning of the section that contained the error. 

```
** Error: image build exited
** Error: reboot to resume the build
```

Sometimes when the source code repositories are busy, they will refuse connections. This is the most common cause of errors in the build process. The build may have to be resumed multiple times. 

### Verifying a successful Build

The Build is successful when the last line of the Build log is:

```
// END
```

Until that line is not output by the script, even if you can login to the web interface, moOde is not completely installed, so please refrain from setting up any options in the web UI. 

## Other Resources

[moodeaudio.org](http://moodeaudio.org) \
[moOde Twitter feed](http://twitter.com/MoodeAudio) \
[Contributors](https://github.com/moode-player/moode/blob/master/www/CONTRIBS.html)
