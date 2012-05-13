DATE=$(date +%Y%m%d)
LOG=$0.$DATE.txt

# find a list of files created/modified today.
# we exclude a bunch of directories with grep exclusions in the pipeline

echo "Finding files to backup..."

find / -mtime 0 | grep -v 'var/lib/dhcp' | grep -v 'var/lock' | grep -v sys | grep -v proc | grep -v run | grep -v 'var/cache' | grep -v 'var/log' | grep -v 'var/lib/collectd' | grep -v '/var/lib/dhcpcd' | grep -v '^/dev/' > $LOG 

# clean the errors from find from the log.
# redirecting STDERR doesn't do the job.
sed -i 's/^find://' $LOG

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


echo "Syncing up with $OTHERHOSTNAME"
cat $LOG
# This copies everything in $LOG
echo "-------------------"

echo "Ready to go? [Y/n]"

read key

case $key in
	Y|y)
	rsync -av / root@$OTHERHOSTNAME:/ --backup --backup-dir=/var/backup/ --suffix=.$(date +%Y%m%sd).bak --files-from=$LOG
	echo "-------------------" ; check_result
	;;

	*)
	echo "Gut check."
	echo "Run $0 again."
	exit 1
	;;
esac

