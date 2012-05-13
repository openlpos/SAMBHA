#!/bin/bash
#
# Tool for performing HA validation actions
# Runs from Util node
#
# wjkennedy@openlpos.org
# Thu May 10 14:21:53 UTC 2012
#########################

INTERVAL=30
TARGET="hot"
FILE=/mnt/ha-test.out.$(date +%Y%m%d)

echo "Checking for SMB mount.."
mount | grep samba
if [ $? -eq 1 ]
then
	echo "No Samba mount found.."
	echo " --> Mounting SMB volume.."
       	mount.cifs //samba/samba /mnt -o user=guest	
	if [ $? -eq 0 ]
	then
		echo "FATAL: Failed to mount SMB volume"
		echo "Ensure heartbeat and VIP are available."
		exit 1
	fi

	touch $FILE
	if [ $? -ne 0 ]
	then
		echo "Failed to touch $FILE"
		echo "FATAL: May not be able to remount or access the Share."
		exit 1
	fi

fi

write_test_file(){
FILE=/mnt/ha-test.out.$(date +%Y%m%d)
echo "Sleeping for $INTERVAL between writes."
echo "continuously writing to $FILE..."
while true
	do
		date >> $FILE
		echo "-----------------" >> $FILE
		sleep $INTERVAL
	done
}


get_status(){

ssh $TARGET '/etc/init.d/drbd status'

}


swap_targets(){
case $TARGET in
	
	hot)
		echo "Target already set to hot."
		echo "Swapping to warm.." ; echo 
		TARGET=warm
	;;

	warm)
		echo "Setting target to hot."
		TARGET=hot
	;;
esac
}

force_standby(){
ssh $TARGET "/usr/share/heartbeat/hb_standby"
}

stop_heartbeat(){
ssh $TARGET "/etc/init.d/heartbeat stop"
}

force_secondary(){
ssh $TARGET "drbdadm secondary all"
}

force_disconnect(){
ssh $TARGET "drbdadm disconnect all"
}

force_reboot(){
ssh $TARGET "telinit 6"
}

force_failover(){
ssh $TARGET /usr/share/heartbeat/hb_standby&
}

force_failback(){
ssh $TARGET "/usr/share/heartbeat/hb_standby"
}

test_host(){
ITERATION=0
TESTNUM=0
while [ $ITERATION -le $INTERVAL ]
do
	ITERATION=$(expr "$ITERATION" + 1)
	echo -n "  --> $ITERATION of $INTERVAL : " ; sleep 5 ; get_status

		case $ITERATION in
		
		10)
			echo "Running test #1 - force reboot" | tee -a $FILE
			force_reboot
		;;

		20)	echo "Running test #2 - force failover" | tee -a $FILE
			force_failover
		;;


		25)	echo "Running test #3 - force failback" | tee -a $FILE
			force_failback
		;;

		esac

	TESTNUM=$(expr "$TESTNUM" + 1 )
			
	if [ $ITERATION -eq $INTERVAL ]
	then
		echo "Max reached - swapping targets.."
		swap_targets
		test_host
	fi
done
}

get_status
write_test_file &
test_host
