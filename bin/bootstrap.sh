#!/bin/bash
INSTALL_DIR=$1;
if [ -d $INSTALL_DIR ];
then
    echo "Directory $INSTALL_DIR already exists!"; 
    exit;
fi
# Check for required applications
ERRORS=0;
for PROGRAM in git curl
do
    if [ ! `which $PROGRAM 2>&-` ];
    then
        ERRORS=1;
        echo "Could not find required program $PROGRAM in path.";
    fi
done
# stop after errors if we got them
if [ $ERRORS -eq 1 ];
then
    exit;
fi
# Checkout the code repository
git clone git://github.com/cshenry/Model-SEED-core $INSTALL_DIR;
# Make the default data dir
DATA_DIR=$INSTALL_DIR/data;
if [ ! -d $DATA_DIR ];
then
    mkdir -p $DATA_DIR;
fi
# Download the base database to tempfile and untar
TMPFILE=`mktemp /tmp/XXXXXXXX`;
curl http://bioseed.mcs.anl.gov/~chenry/data.tgz > $TMPFILE;
tar -xzf $TMPFILE -C $DATA_DIR;
