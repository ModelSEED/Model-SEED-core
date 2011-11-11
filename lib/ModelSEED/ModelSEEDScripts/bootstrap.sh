#!/bin/bash
INSTALL_DIR=$1;
if [ -d $INSTALL_DIR ];
then
    echo "Directory $INSTALL_DIR already exists!"; 
    exit;
fi
# Check for required applications
ERRORS=0;
for PROGRAM in git curl sqlite3
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
echo "Cloning repository git://github.com/ModelSEED/Model-SEED-core";
git clone git://github.com/ModelSEED/Model-SEED-core $INSTALL_DIR;
# Make the default data dir
DATA_DIR=$INSTALL_DIR/data;
if [ ! -d $DATA_DIR ];
then
    mkdir -p $DATA_DIR;
fi
# Download the base database to tempfile and untar
echo "Downloading standard datasets to $INSTALL_DIR/data";
TMPFILE=`mktemp /tmp/XXXXXXXX`;
curl http://bioseed.mcs.anl.gov/~chenry/data.tgz > $TMPFILE;
tar -xzf $TMPFILE -C $DATA_DIR;
# Download the sqlite database
TMPFILE=`mktemp /tmp/XXXXXXXX`;
echo "Downloading biochemistry database to $INSTALL_DIE/data/ModelDB/";
curl http://bioseed.mcs.anl.gov/~chenry/ModelDB-sqlite.tgz > $TMPFILE;
tar -xzf $TMPFILE -C $DATA_DIR;
echo "Loading database into sqlite at $INSTALL_DIE/data/ModelDB/ModelDB.db";
sqlite3 $DATA_DIR/ModelDB/ModelDB.db < $DATA_DIR/ModelDB/ModelDB.sqlite;
rm $DATA_DIR/ModelDB/ModelDB.sqlite;
cd $INSTALL_DIR;
