#!/bin/bash

DRBDLOCALSTATUS=$(/etc/init.d/drbd status | tail -n 1 | awk '{print $3}')
CONFFILE="/etc/fs_variables.txt"
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
