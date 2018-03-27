# Raspbian Installation

## SDCard preparation

In order to install moOde OS you need to have a working Raspbian Stretch Lite release 2017-11-29 (no other release is guaranteed to work) burnt into a SDCard. Detailed instructions can be found on [official page](https://www.raspberrypi.org/documentation/installation/installing-images/README.md).

Then you need to insert the card into a card reader, and mount the boot volume in your usual computer. 

Later, [enable SSH](https://www.raspberrypi.org/documentation/remote-access/ssh/README.md) in your Raspbian. Easiest way is to create an empty file named `ssh`. On a mac this would normally be `cd /Volumes/boot && touch ssh`, on a windows machine the Volumes folder might variate.  

## Login using SSH

Lastly, place the SDCard on the Pi and power it on. We need to login to the Pi using SSH, a secure protocol. First we'll need to know the IP where the RPi is located (generaly something like 192.168.1.xxx). Open terminal in your usual computer and type `ping raspberrypi.local`. Other methods to get the IP are described in the [official documentation](https://www.raspberrypi.org/documentation/remote-access/ip-address.md). Now from your computer terminal you can: `ssh pi@192.168.1.xxx`. Password is `raspberry`.

Now we can start installing moOde.
