#!/bin/bash

RELEASE_TAR="$1"

TAR_FILE=`basename $RELEASE_TAR`
RELEASE_DIR=`dirname $RELEASE_TAR`

CONF_FILE="$RELEASE_DIR/resultparser.conf"

echo "result-parser-archive=$TAR_FILE" > $CONF_FILE
MD5=`openssl dgst -md5 $RELEASE_TAR`
MD5=`echo $MD5 | cut -d= -f2 | sed -e 's/ //g'` 
SHA512=`openssl dgst -sha512 $RELEASE_TAR`
SHA512=`echo $SHA512 | cut -d= -f2 | sed -e 's/ //g'`
echo "result-parser-archive-md5=$MD5" >> $CONF_FILE
echo "result-parser-archive-sha512=$SHA512" >> $CONF_FILE
CODE_DIR=`echo $TAR_FILE | sed -e 's/\.tar\.gz$//g'`
echo "result-parser-dir=$CODE_DIR" >> $CONF_FILE
echo "result-parser-cmd=resultParser.pl" >> $CONF_FILE
VER=`echo $CODE_DIR | cut -d'-' -f2`
echo "result-parser-version=$VER" >> $CONF_FILE
if test "$(uname -s)" == "Darwin"; then
	UUID=`uuidgen -hdr | head -n 1 | awk '{ print $2 }'`
else
	UUID=`uuidgen -t`
fi
echo "result-parser-uuid=$UUID" >> $CONF_FILE



