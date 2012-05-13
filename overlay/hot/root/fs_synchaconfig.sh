#!/bin/bash

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
rsync -av /etc/ha.d/ root@$OTHERHOSTNAME:/etc/ha.d/ --backup --suffix=.$(date +%Y%m%sd).bak
echo "-------------------" ; check_result


echo "Syncing up SAMBA related directories and files.."
# This copies everything in this /etc/samba directory
echo "-------------------"
echo "samba.."
rsync -av /etc/samba/ root@$OTHERHOSTNAME:/etc/samba/ --backup --suffix=$(date +%Y%m%sd).bak
echo "-------------------" ; check_result

echo "Syncing up DRBD related directories and files.."
# This copies everything in this /etc/drbd directory
echo "-------------------"
echo "drbd.."
rsync -av /etc/drbd* root@$OTHERHOSTNAME:/etc/ --backup --suffix=$(date +%Y%m%sd).bak
echo "-------------------" ; check_result

echo "Syncing up Admin scripts.."
# This copies all the shell scripts in /root/"
echo "-------------------"
echo "scripts.."
rsync -av /root/*.sh root@$OTHERHOSTNAME:/root/ --backup --suffix=$(date +%Y%m%sd).bak
echo "-------------------" ; check_result


echo ; echo "Restart heartbeat and DRBD?"
echo "Default is 'no'"
echo ; echo "[y|N]"

read hbrestart

case $hbrestart in
	
	n|N)
		echo "To restart heartbeat, issue /etc/init.d/heartbeat restart on warm and hot hosts."
		echo "To restart DRBD, issue /etc/init.d/drbd restart on warm and hot hosts."
	;;

	y|Y)
		echo "Restarting heartbeat on warm and hot hosts..."
		/etc/init.d/heartbeat stop
		/etc/init.d/heartbeat start
		
		if [ $? -ne 0 ]
		then
			echo "Failed to restart heartbeat.  Investigate and restart manually."
		else
			echo "Stopping heartbeat on $OTHERHOSTNAME"
			ssh $OTHERHOSTNAME /etc/init.d/heartbeat stop
			if [ $? -ne 0 ]
			then
				echo "Failed to restart heartbeat.  Investigate and restart manually."
			else
				echo "watch.."
			fi
				
		
		fi

		echo "Restarting DRBD on warm and hot hosts..."
		echo "Stopping DRBD locally.."
		/etc/init.d/drbd stop

		echo "Starting DRBD on localhost.."
		/etc/init.d/drbd start

		if [ $? -ne 0 ]
		then
			echo "Failed to restart drbd.  Investigate and restart manually."
			exit 1
		else
			echo "Stopping drbd on $OTHERHOSTNAME"
			ssh $OTHERHOSTNAME /etc/init.d/drbd stop
			if [ $? -ne 0 ]
			then
				echo "Failed to stop drbd on $OTHERHOSTNAME.  Investigate and restart manually."
			else
				echo "Starting drbd on $OTHERHOSTNAME"
				ssh $OTHERHOSTNAME /etc/init.d/drbd start
			fi
				
		
		fi

		# Restart heartbeat here and there
		echo "Starting heartbeat on $OTHERHOSTNAME"
		ssh $OTHERHOSTNAME /etc/init.d/heartbeat start
		echo "starting heartbeat locally.."
		/etc/init.d/heartbeat start
	;;

	*)
		echo "To restart heartbeat, issue /etc/init.d/heartbeat restart on warm and hot hosts."
		echo "To restart DRBD, issue /etc/init.d/drbd restart on warm and hot hosts."
	;;

esac 

# Check DRBD status
DRBDLOCALSTATUS=$(/etc/init.d/drbd status | tail -n 1 | awk '{print $3}')

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
        drbdadm primary all
        ssh $OTHERHOSTNAME drbdadm secondary all
	
        ;;
esac

	/etc/init.d/drbd status
