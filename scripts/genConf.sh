#!/bin/bash

if [ $# -ne 4 ]; then
    echo "ERROR: Wrong number of arguments."
    echo "Usage: $0 <CONF_FILE> <TAR> <RELEASE_DIR> <VER>"
    exit 1;
fi

CONF_FILE="$1"
RELEASE_TAR="$2"
RELEASE_DIR="$3"
VER="$4"

TAR_FILE=`basename $RELEASE_TAR`
MD5=`openssl dgst -md5 $RELEASE_TAR |  cut -d= -f2 | sed -e 's/ //g'` 
SHA512=`openssl dgst -sha512 $RELEASE_TAR | cut -d= -f2 | sed -e 's/ //g'`
if test "$(uname -s)" == "Darwin"; then
	UUID=`uuidgen -hdr | head -n 1 | awk '{ print $2 }'`
else
	UUID=`uuidgen -t`
fi

cat > $CONF_FILE <<EOF
result-parser-archive=$TAR_FILE
result-parser-archive-md5=$MD5
result-parser-archive-sha512=$SHA512
result-parser-dir=$RELEASE_DIR
result-parser-cmd=resultParser.pl
result-parser-version=$VER
result-parser-uuid=$UUID
EOF
