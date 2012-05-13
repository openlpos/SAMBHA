#!/bin/bash
#
# Sanity check script
#
#################################################

CONFFILE="/etc/fs_variables.txt"
DATE=$(date +%Y%m%d)
HOMEDIR=/opt/SAMBHA
PUBIP=$(ip addr show | grep eth0 | grep inet | awk -F" " '{print $2}' | awk -F"/" '{print $1}')
DRBDLOCALSTATUS=$(/etc/init.d/drbd status | tail -n 1 | awk '{print $3}')

# Reread the configuration file
echo "Reading configuration parameters.."
. $CONFFILE
echo ; echo ; echo "--------------------------------------------"
cat $CONFFILE
echo "--------------------------------------------"
echo ; echo

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
		echo "FATAL: Failed to get expected hostname."
		exit 1
	;;
esac

# Manage Heartbeat
echo "Preemptively restarting Heartbeat globally.."
/etc/init.d/heartbeat stop
ssh $OTHERHOSTNAME /etc/init.d/heartbeat stop

# Establish DRBD status
case $DRBDLOCALSTATUS in

	Secondary/Unknown)
	DRBDSECONDARY=1
	ssh $OTHERHOSTNAME drbdadm primary all
	drbdadm disconnect all
	drbdadm -- --discard-my-data connect all
;;

	Primary/Unknown)
	DRBDPRIMARY=1
	ssh $OTHERHOSTNAME drbdadm disconnect all
	ssh $OTHERHOSTNAME drbdadm -- --discard-my-data connect all
	;;

	*)
	echo "Undesirable DRBD status discovered.."
	echo "Attempting to force state."
	echo
	ssh $OTHERHOSTNAME drbdadm secondary all
	ssh $OTHERHOSTNAME drbdadm disconnect all
	ssh $OTHERHOSTNAME drbdadm -- --discard-my-data connect all
	ssh $OTHERHOSTNAME drbdadm secondary all
	;;
esac



# Check LVM status.
# Bring volume group to active status

echo "Forcing Volume Group online.."
vgchange -a y drbdsamba0vg

if [ ! -z DRBD_PRIMARY ]

then
	echo "Forcing primary status for DRBD volume.."
	drbdadm secondary all
	drbdadm disconnect all
	drbdadm -- --discard-my-data connect all
fi

/etc/init.d/heartbeat start

case $MYHOSTNAME in

		hot)
			echo "Services managed in /etc/ha.d/haresources should automatically fail back to this server."
		;;

		*)
			echo "Services should fail back to hot."
		;;
esac

echo "Checking drbd status:"
echo -n "Local: "
drbdadm status | grep samba0 | awk -F'="' '{print $4}'

echo -n "Remote: "
ssh $OTHERHOST drbdadm status | grep samba0 | awk -F'="' '{print $4}'

if [ ! -d /var/run/resource-agents ]
then
	echo "Creating /var/run/resource-agents/ directory.."
	mkdir /var/run/resource-agents/
fi

# Manage Heartbeat
echo "Restarting Heartbeat Globally.."
ssh $OTHERHOSTNAME /etc/init.d/heartbeat start
/etc/init.d/heartbeat start

