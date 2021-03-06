#!/bin/bash

OUTPUT_DIR="$1"
VERSION="$2"

if [ $# -ne 2 ]; then
    echo "Usage;  $0 <OUTPUT_DIR> <VERSION>"
    exit 1
fi

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
COMM_PARSERS="ps-ctest.pl ps-jtest.pl gt-csonar.pl rl-goanna.pl coverity.pl"
SRC_DIR="$CURRENT_DIR/.."
SCRIPTS_DIR="$SRC_DIR/scripts"
UTIL_DIR="$CURRENT_DIR"
SCARF_XML_LIB_DIR="$SRC_DIR/swamp-scarf-io"
SARIF_JSON_LIB_DIR="$SRC_DIR/swamp-sarif-io"
SCARF_XML_LIB_FILES="$SCARF_XML_LIB_DIR/perl/ScarfXmlWriter.pm"
SCARF_XML_LIB_FILES+=" $SCARF_XML_LIB_DIR/perl/ScarfXmlReader.pm $SCARF_XML_LIB_DIR/perl/SwampXML.pm"
SARIF_JSON_LIB_FILES="$SARIF_JSON_LIB_DIR/SarifJsonWriter.pm"

function CreateReleaseTar
{
    if [ $# -lt 4 ]; then
	echo "CreateReleaseTar called with <4 parameters ($#)"
	exit 1
    fi

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
    local NOARCH_DIR="$INSTALL_DIR/noarch"
    local INFILES_DIR="$NOARCH_DIR/in-files"
    local INNERTAR_DIR="$INFILES_DIR/$INSTALL_DIRNAME"
    local GENCONF="$UTIL_DIR/genConf.sh"
    local CONF_FILE="$INFILES_DIR/resultparser.conf"
    local VERSION_TXT="$INNERTAR_DIR/version.txt"
    local RESULTPARSERDEFAULTSCONF="$INNERTAR_DIR/resultParserDefaults.conf"
    local INNERTAR="$INNERTAR_DIR.tar.gz"
    local MD5SUM="$INSTALL_DIR/md5sum"

    git submodule init
    if [ $? -ne 0 ]; then
	echo "ERROR: git submodule init failed \$?=$?"
	exit 1
    fi

    git submodule update --init --recursive
    if [ $? -ne 0 ]; then
	echo "ERROR: git submodule update --init --recursive failed \$?=$?"
	exit 1
    fi

    for d in $INSTALL_DIR $NOARCH_DIR $INFILES_DIR $INNERTAR_DIR; do
	mkdir $d
	if [ $? -ne 0 ]; then
	    echo "Unable to mkdir $d"
	    exit 1
	fi
    done

    cp -rf $SCRIPTS_DIR/* $INNERTAR_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp -rf $SCRIPTS_DIR/* $INNERTAR_DIR
	exit 1
    fi

    cp $SCARF_XML_LIB_FILES $SARIF_JSON_LIB_FILES $INNERTAR_DIR
    if [ $? -ne 0 ]; then
        echo FAILED: cp -rf $SCARF_XML_LIB_FILES $SARIF_JSON_LIB_FILES $INNERTAR_DIR
        exit 1
    fi

    for f in "$@"; do
	local file="$INNERTAR_DIR/$f"
	if [ -f $file ] || [ -L $file ]; then
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

    for f in $INNERTAR_DIR/*.pl; do
	perl -c -I $INNERTAR_DIR $f >& /dev/null;
	if [ $? -ne 0 ]; then
	    echo FAILED: perl -c -I $INNERTAR_DIR $f
	    echo ---
	    perl -c -I $INNERTAR_DIR $f
	    exit 1
	fi
    done

    rm -f $VERSION_TXT
    echo "$VER" > $VERSION_TXT

    if [ -f $RESULTPARSERDEFAULTSCONF ]; then
	echo "parserFwVersion = $VER" >> $RESULTPARSERDEFAULTSCONF
    else
	echo "Error: $RESULTPARSERDEFAULTSCONF not found"
	exit 1
    fi

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

    cp -p $SRC_DIR/lib/* $INFILES_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp -p $SRC_DIR/lib/* $INFILES_DIR
	exit 1
    fi

    cp -rp $SRC_DIR/swamp-conf $NOARCH_DIR
    if [ $? -ne 0 ]; then
	echo FAILED: cp -rp $SRC_DIR/swamp-conf $NOARCH_DIR
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

    echo "Release TAR is available $OUTERTAR"
}


CreateReleaseTar resultparser $VERSION $SRC_DIR $OUTPUT_DIR
# CreateReleaseTar resultparser noncomm-$VERSION $SRC_DIR $OUTPUT_DIR $COMM_PARSERS

exit 0
