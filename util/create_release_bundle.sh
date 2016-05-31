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

TARGET_DIR="$OUTPUT_DIR/resultparser-$VERSION"

mkdir -p $TARGET_DIR/in-files/resultparser-$VERSION
RESULT=$?
if [[ $RESULT != 0 ]]; then
        echo "Failed to create $TARGET_DIR"
        exit 99
fi

cp -rf ../scripts/* $TARGET_DIR/in-files/resultparser-$VERSION

rm -f $TARGET_DIR/in-files/resultparser-$VERSION/version.txt
echo "Result Parser $VERSION" > $TARGET_DIR/in-files/resultparser-$VERSION/version.txt

cd $TARGET_DIR/in-files/
tar czf resultparser-$VERSION.tar.gz resultparser-$VERSION

./resultparser-$VERSION/genConf.sh resultparser-$VERSION.tar.gz
cd $CURRENT_DIR
rm -rf $TARGET_DIR/in-files/resultparser-$VERSION


cp -f ../lib/* $TARGET_DIR/in-files

cp -rf ../swamp-conf $TARGET_DIR

cp ../RELEASE_NOTES.txt $TARGET_DIR

cd $TARGET_DIR

find . -type f -exec md5sum {} \; > md5sum

cd $CURRENT_DIR
cd $OUTPUT_DIR

tar cf resultparser-$VERSION.tar resultparser-$VERSION

cd $CURRENT_DIR

rm -rf $TARGET_DIR

echo "Release TAR is available $OUTPUT_DIR/resultparser-$VERSION.tar"

exit 0
