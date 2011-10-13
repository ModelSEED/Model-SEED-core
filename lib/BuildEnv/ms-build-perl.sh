#!/bin/sh

PERLBREWURL=https://raw.github.com/gugod/App-perlbrew/master/perlbrew
TMPDIR=$1;
if [ -z "$TMPDIR" ]; then
    if [ -d "/tmp" ]; then
        TMPDIR="/tmp"
    else
        TMPDIR="."
    fi
fi

cd $TMPDIR

echo
if type curl >/dev/null 2>&1; then
  echo "## Download the latest perlbrew"
  curl -k -Lo perlbrew $PERLBREWURL >/dev/null 2>&1
elif type wget >/dev/null 2>&1; then
  echo "## Download the latest perlbrew"
  wget --no-check-certificate -O perlbrew $PERLBREWURL >/dev/null 2>&1
else
  echo "Need wget or curl to use $0"
  exit 1
fi

echo
echo "## Installing perlbrew"
chmod +x perlbrew
./perlbrew install

echo "## Installing patchperl"
./perlbrew -fq install-patchperl

echo "## Installing cpanm"
./perlbrew -fq install-cpanm

./perlbrew install --force 5.12.3
./perlbrew switch 5.12.3

echo
echo "## Done."
rm ./perlbrew
