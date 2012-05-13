file /etc/ha.d/authkeys

if $? -ne 0
then
	echo "Failed to read authkeys file."
	exit 1
fi

echo "Creating /etc/ha.d/authkeys.."
echo "-------------------------------------"
echo "# Automatically generated authkeys file" | tee -a /etc/ha.d/authkeys
echo "auth 1" | tee -a /etc/ha.d/authkeys
echo -n "1 sha1" ; echo "$(dd if=/dev/urandom count=4 2>/dev/null | md5sum | cut -c1-32)" | tee -a /etc/ha.d/authkeys
echo "-------------------------------------"
