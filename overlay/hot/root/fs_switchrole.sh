#!/bin/bash
#
# Setup and Initialization script for SAMBHA
#
# This version is modified to create only *one* DRBD
# volume.  A single PV, and a single VG and LV, which is used as drbd0
#
# References to DRBDVOL1 were deleted.  Patch to replace.
#################################################

CONFFILE="/etc/fs_variables.txt"
DATE=$(date +%Y%m%d)
HOMEDIR=/opt/SAMBHA
PUBIP=$(ip addr show | grep eth0 | grep inet | awk -F" " '{print $2}' | awk -F"/" '{print $1}')

# Check for the base directory for storing config, backups, etc..
if [ -d $HOMEDIR ]
then
	echo "Creating $HOMEDIR.."
else
	echo "Using existing $HOMEDIR"
fi

#########################################
# Backup existing $1
backup_existing(){

echo " --> Backing up existing $1.."

mkdir -p $HOMEDIR/$DATE
rsync -a $1 $HOMEDIR/$DATE/

if [ $? -ne 0 ]
then
	echo "Couldn't create backup for $1"
else
	echo "Backed up to $HOMEDIR/$DATE/$1"
fi

} #########################################




# Build local configuration file
build_hot_conf(){

if [ -f $CONFFILE ]
then
	echo "Reading existing configuration file.."
	. $CONFFILE

	echo "Archiving existing SAMBHA configuration.."
	echo "-------------------"
	backup_existing $CONFFILE
	echo "-------------------"
else
	echo "No config file exists.."
fi

echo "Building new hot role configuration file in $CONFFILE.."
cat > $CONFFILE << EOF
PUBIP=$PUBIP
VIPADDR=192.168.1.137
VIPNIC="eth0:1"
HOSTNAME="hot"
OTHERHOST="warm"
HBEATIP=192.168.9.11
DRBDIP=192.168.10.11
OTHERIP=10.3.0.201
DOMAIN=WORKGROUP
HACONFHOME="/etc/ha.d"
DRBDCONFHOME="/etc/drbd.d/"
HOMEDIR="/etc/SAMBHA/"
DRBDPV0=
DRBDMETA="internal"
EOF
echo ; echo

if [ -z $OTHERIP ]
then
	echo "Enter the IP address of the other host:"
	read OTHERIP
	echo "OTHERIP=$OTHERIP" >> $CONFFILE
	echo ; echo ; echo "--------------------------------------------"
	echo "Change OTHERIP property in /etc/hosts or rerun $0 to change."
	echo "--------------------------------------------"
fi
}


build_warm_conf(){

if [ -f $CONFFILE ]
then
	echo "Reading existing configuration file.."
	. $CONFFILE

	echo "Archiving existing SAMBHA configuration.."
	echo "-------------------"
	backup_existing $CONFFILE
	echo "-------------------"
else
	echo "No config file exists.."
fi

echo "Building new hot role configuration file in $CONFFILE.."
cat > $CONFFILE << EOF
PUBIP=$PUBIP
VIPADDR=192.168.1.137
VIPNIC="eth0:1"
HOSTNAME="warm"
OTHERHOST="hot"
HBEATIP=192.168.9.12
DRBDIP=192.168.10.12
OTHERIP=10.3.0.200
DOMAIN=WORKGROUP
HACONFHOME="/etc/ha.d"
DRBDCONFHOME="/etc/drbd.d/"
HOMEDIR="/etc/SAMBHA/"
DRBDPV0=
DRBDMETA="internal"
EOF
echo ; echo

if [ -z $OTHERIP ]
then
	echo "Enter the IP address of the other host:"
	read OTHERIP
	echo "OTHERIP=$OTHERIP" >> $CONFFILE
	echo ; echo ; echo "--------------------------------------------"
	echo "Change OTHERIP property in /etc/hosts or rerun $0 to change."
	echo "--------------------------------------------"
fi
}


reload_conf(){
# Reread the configuration file
echo "Reading new configuration parameters.."
. $CONFFILE
echo ; echo ; echo "--------------------------------------------"
cat $CONFFILE
echo "--------------------------------------------"
echo ; echo
}

# Find volumes
find_volumes(){
echo
echo "Root filesytem resides on:"
grep '^/' /proc/mounts | cut -f1 -d" "
ROOTDEV=$(grep '^/' /proc/mounts | cut -f1 -d" ")
#blockdev --report | grep -v $ROOTDEV

echo "Available devices:"
blockdev --report | grep -v $ROOTDEV

echo "-------------------------------"
echo ; echo
echo "Block device for drbdsamba0 PV?"
echo "This is the primary Physical Volume to house the DRBD Logical filesystem, 'drbd0'"
echo ; echo "  Enter as '/dev/sdc'"
read DRBDPV0
echo "DRBDPV0=$DRBDPV0" >> $CONFFILE
echo ; echo 
echo "=================================================================================="
echo "Volume groups and logical volumes will be created on $DRBDPV0 and $DRBDPV1"
echo "If this is the intended behavior, type 'Yes'. Anything else returns to disk selection."
echo "=================================================================================="
read MKDRBDPV
case $MKDRBDPV in

	Yes)
		MKDRBDPV=1
		beep
		echo ; echo ; echo ; echo "============================================================"
		echo "$DRBDPV0 will be destroyed and/or rebuilt."
		echo "============================================================"
		echo ; echo
	;;

	*)
		echo "Balking at selection.."
		find_volumes

	;;
esac
}

# Prepare volumes
prep_os_volumes(){

if [ $MKDRBDPV -eq 1 ]
then
	echo "$DRBDPV0 will be created or deleted and rebuilt as required.."
else
	echo "No disks identified for prep."
	break
fi

# Physical Volumes
# This version is modified to create only *one* DRBD
# volume.  A single PV, and a single VG and LV, which is used as drbd0
#
# Primary DRBD volume
# $DRBDPV0
pvs | grep $DRBDPV0
if [ $? -ne 1 ]
then
	echo "Found $DRBDPV0 in existing list of Physical volumes.."
	echo "Removing. (destructive)"
	pvremove -ff $DRBDPV0
	pvcreate $DRBDPV0
else
	echo "No preexisting volume.."
	pvcreate $DRBDPV0
fi

# Volume Groups
#
# Primary DRBD volume group
# drbdsamba0vg
vgs | grep $DRBDPV0
if [ $? -ne 1 ]
then
	echo "Found $DRBDPV0 in existing list of Volume groups.."
	echo "Removing. (destructive)"
	vgremove drbdsamba0vg  
	echo "Creating DRBD Volume group for $DRBDPV0"
	vgcreate drbdsamba0vg $DRBDPV0 
else
	echo "No preexisting volume.."
	vgcreate drbdsamba0vg $DRBDPV0 
fi

# size the disks..

# Get the size of the volume groups in Megabytes

GROUP=1
while [ $GROUP -le 2 ]
do
	for VGSIZE in $(vgs --units m | awk '{print $6}' | grep -v 'VSize' | cut -f1 -d'.')
	do
		echo "LVM Group $GROUP size available: $VGSIZE"
		RCMDLVMSZ=$(expr $(expr $VGSIZE - 1024) / 2)
		echo "Recommended Logical Volume size: $RCMDLVMSZ"
		GROUP=$(expr $GROUP + 1)
	done
done

# Primary DRBD logical volume
# drbdsamba0lv
lvs | grep drbdsamba0lv
if [ $? -ne 1 ]
then
	echo "Found drbdsamba0lv in existing list of Volume groups.."
	echo "Removing. (destructive)"
	lvremove -f drbdsamba0vg/drbdsamba0lv  
	echo "Creating DRBD Logical Volume drbdsamba0lv"
	lvcreate -n drbdsamba0lv -L "$RCMDLVMSZ"M drbdsamba0vg --mirrorlog core
else
	echo "No preexisting volume.."
	echo "Creating DRBD Logical Volume drbdsamba0lv"
	lvcreate -n drbdsamba0lv -m 1 -L "$RCMDLVMSZ"M drbdsamba0vg --mirrorlog core
fi
}

########################
# Build HA configuration
build_haconf(){
# /etc/ha.d and friends
echo "Heartbeat configuration.."
echo
backup_existing /etc/ha.d

#harc
#rc.d
#README.config
#resource.d
#shellfuncs

}
########################



############################################################
# Push HA configuration
push_haconf(){
#scp CONFHOMEs to OTHERHOST
echo "Pushing HA configuration to the other member.."
# Find out where we are
HOSTNAME=$(uname -n)

case $HOSTNAME in

	hot)
		echo "I am the Hot server.."
		MYHOSTNAME="hot"
		OTHERHOSTNAME="warm"
	;;

	warm)
		echo "I am the Warm server.."
		MYHOSTNAME="warm"
		OTHERHOSTNAME="hot"
	;;

	*)
		echo "FATAL: Failed to get hostname."
		exit 1
	;;
esac




# If we can't perform the rsync operation, error out
check_result(){

if [ $? -ne 0 ]
then
	echo "Error synchronizing directory.  Check connection to $OTHERHOSTNAME."
	echo "-------------------"
	echo "/etc/hosts says:"
	grep $OTHERHOSTNAME /etc/hosts
	echo "-------------------"
fi

}

echo "Syncing up HA related directories and files to $OTHERHOSTNAME"
# This copies everything in this ha.d directory
echo "-------------------"
echo "ha.d.."
rsync -a /etc/ha.d/ root@$OTHERHOSTNAME:/etc/ha.d/ --backup --suffix=.$(date +%Y%m%sd).bak
echo "-------------------" ; check_result


echo "Syncing up SAMBA related directories and files.."
# This copies everything in this /etc/samba directory
echo "-------------------"
echo "samba.."
rsync -a /etc/samba/ root@$OTHERHOSTNAME:/etc/samba/ --backup --suffix=$(date +%Y%m%sd).bak
echo "-------------------" ; check_result

}
############################################################

# Build hosts file
build_hosts(){
backup_existing /etc/hosts

echo "Creating new /etc/hosts file..."
cat > /etc/hosts << EOF
#
# hosts         This file describes a number of hostname-to-address
#               mappings for the TCP/IP subsystem.  It is mostly
#               used at boot time, when no name servers are running.
#               On small systems, this file can be used instead of a
#               "named" name server.
# Syntax:
#    
# IP-Address  Full-Qualified-Hostname  Short-Hostname
#

127.0.0.1	localhost

# special IPv6 addresses
::1             localhost ipv6-localhost ipv6-loopback

fe00::0         ipv6-localnet

ff00::0         ipv6-mcastprefix
ff02::1         ipv6-allnodes
ff02::2         ipv6-allrouters
ff02::3         ipv6-allhosts

$VIPADDR	sambha

$OTHERIP	warm
192.168.9.12	warm-drbd
192.168.10.12	warm-heartbeat

$PUBIP	hot
192.168.9.11	hot-drbd
192.168.10.11	hot-heartbeat
EOF

}

# Join domain
join_domain(){
# Winbind magic
echo
}

# Configure VIP
make_vip(){
echo "Configuring Virtual IP.."
echo "This may not be necessary if Heartbeat or Pacemaker handle it."
echo
}


# Run

case $1 in

	-w|--warm)
		echo "Making this the Warm host.."
		build_warm_conf
	;;


	-h|--hot)
		echo "Making this the Hot host.."
		build_hot_conf
	;;
	
	*)
		echo
		echo "$0 [-h|-w] or [--hot|--warm]"
		echo "switches machine role from hot to warm or vice-versa."
		echo
		exit 1
	;;
esac

