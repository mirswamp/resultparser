#!/bin/bash

OUTPUT_DIR="$1"
VERSION="$2"

CURRENT_DIR=`pwd`

echo "OUTPUT DIR : $OUTPUT_DIR"

if [[ "$VERSION" = "" ]]; then
	VERSION=`git tag | tail -n 1`
fi

if [[ "$VERSION" = "" ]]; then
        echo "Version Number not found!!"
	exit 99
fi

echo "VERSION : $VERSION"

PARSER_DIRNAME="resultparser-$VERSION"
INSTALL_DIR="$OUTPUT_DIR/$PARSER_DIRNAME"
PARSER_NONCOMM_DIRNAME="resultparser-noncomm-$VERSION"
INSTALL_NONCOMM_DIR="$OUTPUT_DIR/$PARSER_NONCOMM_DIRNAME"
COMM_PARSERS="ps-ctest.pl ps-jtest.pl gt-csonar.pl rl-goanna.pl"
SRC_DIR="$CURRENT_DIR/.."


function CreateReleaseTar
{
    local NAME="$1"
    shift
    local VER="$1"
    shift
    local SRC_DIR="$1"
    shift
    local OUT_DIR="$1"
    shift

    local PARSER_DIRNAME="$NAME-$VER"
    local INSTALL_DIRNAME="$PARSER_DIRNAME"
    local INSTALL_DIR="$OUT_DIR/$INSTALL_DIRNAME"
    local OUTERTAR="$OUT_DIR/$PARSER_DIRNAME.tar"
    local INFILES_DIR="$INSTALL_DIR/in-files"
    local INNERTAR_DIR="$INFILES_DIR/$INSTALL_DIRNAME"
    local GENCONF="$SRC_DIR/scripts/genConf.sh"
    local CONF_FILE="$INFILES_DIR/resultparser.conf"
    local VERSION_TXT="$INNERTAR_DIR/version.txt"
    local INNERTAR="$INNERTAR_DIR.tar.gz"
    local MD5SUM="$INSTALL_DIR/md5sum"

    for d in $INSTALL_DIR $INFILES_DIR $INNERTAR_DIR; do
	mkdir $d
	if [ $? -ne 0 ]; then
	    echo "Unable to mkdir $d"
	    exit 1
	fi
    done

    cp -rf $SRC_DIR/scripts/* $INNERTAR_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp -rf $SRC_DIR/scripts/* $INNERTAR_DIR
	exit 1
    fi

    for f in "$@"; do
	local file="$INNERTAR_DIR/$f"
	if [ -f $file ]; then
	    rm $file
	    if [ $? -ne 0 ]; then
		echo FAILED: rm $file
		exit 1
	    fi
	else
	    echo "Commercial tool $file not found"
	    exit 1
	fi
    done

    rm -f $VERSION_TXT
    echo "Result Parser $VER" > $VERSION_TXT

    tar czf $INNERTAR -C $INFILES_DIR $INSTALL_DIRNAME
    if [ $? -ne 0 ]; then
	echo FAILED: rm $file
	exit 1
    fi

    $GENCONF $CONF_FILE $INNERTAR $INSTALL_DIRNAME $VER
    if [ $? -ne 0 ]; then
	echo FAILED: $GENCONF $CONF_FILE $INNERTAR $INSTALL_DIRNAME $VER
	exit 1
    fi

    cp -p $SRC_DIR/lib/* $INSTALL_DIR/in-files
    if [ $? -ne 0 ]; then
	echo FAILED: cp -p $SRC_DIR/lib/* $INSTALL_DIR/in-files
	exit 1
    fi

    cp -rp $SRC_DIR/swamp-conf $INSTALL_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp -rp $SRC_DIR/swamp-conf $INSTALL_DIR
	exit 1
    fi

    cp $SRC_DIR/RELEASE_NOTES.txt $INSTALL_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp $SRC_DIR/RELEASE_NOTES.txt $INSTALL_DIR
	exit 1
    fi

    ( cd $INSTALL_DIR; find . -type f -exec md5sum {} \; ) > $MD5SUM

    rm -rf $INNERTAR_DIR

    tar cf $OUTERTAR -C $OUT_DIR $PARSER_DIRNAME
    if [ $? -ne 0 ]; then
	echo FAILED: tar cf $OUTERTAR -C $OUT_DIR $PARSER_DIRNAME
	exit 1
    fi

    rm -rf $INSTALL_DIR

    echo "Release TAR is available $OUTPUT_DIR/resultparser-$VERSION.tar"
}


CreateReleaseTar resultparser $VERSION $SRC_DIR $OUTPUT_DIR
CreateReleaseTar resultparser noncomm-$VERSION $SRC_DIR $OUTPUT_DIR $COMM_PARSERS

exit 0
