#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$name]..."

#======================================
# SuSEconfig
#--------------------------------------
echo "** Running suseConfig..."
suseConfig

echo "** Running ldconfig..."
/sbin/ldconfig

sed --in-place -e 's/icewm/icewm-session/' /usr/bin/wmlist

#======================================
# WebYast Configuration
#--------------------------------------
echo '** Configuring WebYast...'
insserv yastwc
insserv yastws

#======================================
# RPM GPG Keys Configuration
#--------------------------------------
echo '** Importing GPG Keys...'
rpm --import /studio/studio_rpm_key_0
rm /studio/studio_rpm_key_0
rpm --import /studio/studio_rpm_key_1
rm /studio/studio_rpm_key_1
rpm --import /studio/studio_rpm_key_2
rm /studio/studio_rpm_key_2
rpm --import /studio/studio_rpm_key_3
rm /studio/studio_rpm_key_3
rpm --import /studio/studio_rpm_key_4
rm /studio/studio_rpm_key_4
rpm --import /studio/studio_rpm_key_5
rm /studio/studio_rpm_key_5
rpm --import /studio/studio_rpm_key_6
rm /studio/studio_rpm_key_6
rpm --import /studio/studio_rpm_key_7
rm /studio/studio_rpm_key_7
rpm --import /studio/studio_rpm_key_8
rm /studio/studio_rpm_key_8
rpm --import /studio/studio_rpm_key_9
rm /studio/studio_rpm_key_9

sed --in-place -e 's/# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Enable sshd
chkconfig sshd on

#======================================
# Setting up overlay files 
#--------------------------------------
echo '** Setting up overlay files...'
echo mkdir -p /root/
mkdir -p /root/
echo tar xfp /image/1cd018148e77325b492de341a17efcf1 -C /root/
tar xfp /image/1cd018148e77325b492de341a17efcf1 -C /root/
echo rm /image/1cd018148e77325b492de341a17efcf1
rm /image/1cd018148e77325b492de341a17efcf1
mkdir -p /
mv /studio/overlay-tmp/files///samba-config.tar.bz2 //samba-config.tar.bz2
chown root:root //samba-config.tar.bz2
chmod 644 //samba-config.tar.bz2
mkdir -p /etc/
mv /studio/overlay-tmp/files//etc//issue /etc//issue
chown nobody:nobody /etc//issue
chmod 644 /etc//issue
mkdir -p /etc/sysconfig/
mv /studio/overlay-tmp/files//etc/sysconfig//SuSEfirewall2 /etc/sysconfig//SuSEfirewall2
chown root:root /etc/sysconfig//SuSEfirewall2
chmod 666 /etc/sysconfig//SuSEfirewall2
mkdir -p /etc/sysconfig/
mv /studio/overlay-tmp/files//etc/sysconfig//syslog /etc/sysconfig//syslog
chown root:root /etc/sysconfig//syslog
chmod 644 /etc/sysconfig//syslog
chown root:root /etc/init.d/suse_studio_custom
chmod 755 /etc/init.d/suse_studio_custom
test -d /studio || mkdir /studio
cp /image/.profile /studio/profile
cp /image/config.xml /studio/config.xml
rm -rf /studio/overlay-tmp
true