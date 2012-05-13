#!/bin/bash
#
# Glue to clone system via Kiwi
#

PRODUCT=SAMBHA
BUILD=paleo
VERSION=0
DATE=$(date +%Y%m%d)

echo "Capturing system via Kiwi.."

kiwi  --migrate $PRODUCT-v.$VERSION-$BUILD.$DATE

echo "Creating tarball of this Kiwi package as $PRODUCT-v.$VERSION-$BUILD.$DATE.tar"
tar -cvf /tmp/$PRODUCT-v.$VERSION-$BUILD.$DATE.tar /tmp/$PRODUCT-v.$VERSION-$BUILD.$DATE.tar

echo "Follow Kiwi/AutoYaST procedure to rebuild this system locally"
echo "Otherwise, import Kiwi and root tarball into SUSE Studio"
echo "You must also remove the Heartbeat UUID from the filesystem at build time."
