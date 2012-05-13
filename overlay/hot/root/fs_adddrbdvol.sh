#!/bin/bash
#
# Tool for integrating additional storage into DRBD
#
# wjkennedy@openlpos.org
#
############################################

MOUNTED=$(mount | awk '{print $1}' | grep '^/dev')

echo "Mounted filesystems:"
echo "$MOUNTED"


echo "------------------------------"
echo "Physical Volumes known to LVM:"
pvs
echo "------------------------------"
echo
echo "------------------------------"
echo "Volume Groups known to LVM:"
vgs
echo "------------------------------"
echo
echo "------------------------------"
echo "Logical Volumes known to LVM:"
lvs
echo "------------------------------"
echo

echo "------------------------------"
echo "Finding unallocated disks.."
blockdev --report | grep -ev $MOUNTED

