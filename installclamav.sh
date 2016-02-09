#!/bin/bash

# This script is intented to install the clamav package.
# It will first attempt an apt-get install.
# If that fails, it will then download, compile, and install from binaries.
# The libssl-dev package is a dependency and will also be installed.
# The URL used to download the binaries is statically set. It can be
#   modified at the clamURL variable below.
# 
# This script has only been tested on the Kali Linux 2.0 amd64 distribution
#   (2015-06-03 release).
# This script comes without warranty of any kind. By using this script, you
#   are agreeeing to release the author of any liability for damage or loss
#   of data caused by its use. You use this script at your own risk.
#
# Created by Michael Sartori on Feb 9, 2016
#   (Michael.Sartori@GeorgianCollege.ca)


# modify this value to change the location of the binaries archive file
# ***IMPORTANT*** the script expects this file to be a .tar.gz and will not function properly otherwise
clamURL="http://www.clamav.net/downloads/production/clamav-0.99.tar.gz"



tgzfile=`echo $clamURL | rev | cut -d'/' -f1 | rev`
tgzdir=`echo $tgzfile | sed 's/.tar.gz$//'`

function cleanup {
	echo -e "\nRemoving temporary files...\n"
	rm -rf /tmp/clamtmp
	if [ $? != 0 ]; then
		echo -e "\nThere was an error while attempting to remove the temporary directory /tmp/clamtmp"
		exit 1
	fi
}
function errchk {
	if [ $? != 0 ]; then
		echo -e $1
		cleanup
		exit 1
	fi
}


if [ `id -u` != 0 ]; then
	echo "You must run this script as root. Exiting..."
	exit 126
fi


apt-get update
echo -e "\nAttempting to install clamav from repository...\n"
apt-get install clamav -y 2>/dev/null
if [ $? == 0 ]; then
	echo -e "\nclamav was successfully installed"
	exit 0
else
	echo -e "\nSwitching to manual control, captain..."
fi


echo -e "Downloading binaries...\n"
mkdir -p /tmp/clamtmp
cd /tmp/clamtmp
wget -O $tgzfile $clamURL
errchk "\nThere was an error while attempting to download file $clamURL\nExiting..."


echo -e "\nExtracting archive..."
tar -xzf $tgzfile
errchk "\nThere was an error while attempting to extract the archive. Exiting..."


echo -e "\nInstalling libssl-dev package...\n"
apt-get install -y --force-yes libssl-dev
errchk "\nThere was an error while attempting to install the libssl-dev package. Exiting..."


echo -e "\nConfiguring...\n"
cd $tgzdir
./configure
errchk "\nAn error occurred while running the configure script. Exiting..."


echo -e "\nCompiling...\n"
make
errchk "\nThere was an error while compiling. Exiting..."


echo -e "\nInstalling...\n"
make install
errchk "\nThere was an error while installing. Exiting..."
ldconfig


echo -e "\nCreating /usr/local/etc/freshclam.conf file"
cd /usr/local/etc
cp freshclam.conf.sample freshclam.conf
errchk "There was an error creating the file. Exiting..."
linenum=$(( `grep -n "# Comment or remove the line below." freshclam.conf | grep -Eo '^[^:]+'` + 1 ))
sed -i "$linenum s/^/# /" freshclam.conf


echo -e "\nCreating clamav user..."
useradd clamav 2>/dev/null
if [ $? == 9 ]; then
	echo "User account already exists."
else
	errchk "There was an error while attempting to create the clamav user. Exiting..."
fi


echo -e "\nCreating directory /usr/local/share/clamav"
mkdir -p /usr/local/share/clamav
errchk "There was an error while attempting to create the directory. Exiting..."
chown clamav:clamav /usr/local/share/clamav


read -p "All Done! Would you like to run freshclam now [Y/n]? "
runfreshclam=`echo $REPLY | tr '[:upper:]' '[:lower:]'`
if [ "$runfreshclam" == "y" ] || [ "$runfreshclam" == "yes" ] || [ "$runfreshclam" == "" ]; then
	freshclam
fi
cleanup
exit 0
