#!/bin/bash

set -e

cd "$(dirname "$0")"
cd ../../

# check if .root file exists
if [ ! -f .root ]; then
    echo "malformed project structure, missing .root file"
    exit 1
fi

ORIG_DIR=$(pwd)
TARGET_DIR="/Users/qaq/Bootstrap/GitHub/Rayon"

# check if ORIG_DIR has prefix 
if [[ $ORIG_DIR != "/Users/qaq/Bootstrap/"* ]]; then
    echo "this script is used to sync commit on @Lakr233 device, do not run it!"
    exit 1
fi

# check if target exists
if [ ! -d $TARGET_DIR ]; then
    echo "target directory $TARGET_DIR does not exist"
    exit 1
fi
# check if file target/.root exists
if [ ! -f $TARGET_DIR/.root ]; then
    echo "target directory $TARGET_DIR is not a Rayon project"
    exit 1
fi

echo "Syncing from $ORIG_DIR to $TARGET_DIR"

# check if git repo at ORIG_DIR has uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "git repo at $ORIG_DIR has uncommitted changes"
    exit 1
fi

# clean our project first
git clean -fdx

# remove everything at target
rm -rf $TARGET_DIR/* # not .file at root

# copy over
cp -r $ORIG_DIR/* $TARGET_DIR

PROHIBIT_FILE_LIST=(
    "Application/mRayon/mRayon/Application/Assets.xcassets/Avatar.imageset"
    "Application/mRayon/mRayon/Application/Assets.xcassets/Placeholder"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-128.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-128@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-16.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-16@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-20-ipad.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-20@2x-ipad.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-20@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-20@3x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-256.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-256@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-29-ipad.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-29.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-29@2x-ipad.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-29@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-29@3x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-32.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-32@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-40.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-40@2x-1.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-40@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-40@3x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-512.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-512@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-60@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-76.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-76@2x.png"
    "Application/mRayon/mRayon/Application/Assets.xcassets/AppIcon.appiconset/icon-83.5@2x.png"

    "Application/Rayon/Application/Assets.xcassets/Avatar.imageset"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-128.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-128@2x.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-16.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-16@2x.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-256.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-256@2x.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-512.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-512@2x.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-32.png"
    "Application/Rayon/Application/Assets.xcassets/AppIcon.appiconset/icon-32@2x.png"

    "External/CodeMirrorUI/.git"
    "External/NSRemoteShell/.git"
    "External/NSRemoteShell/.gitmodules"
    "External/NSRemoteShell/External/CSSH/.git"
    "External/XTerminalUI/.git"

    "Workflow/Certificates/"
)

# remove prohibited files
for file in "${PROHIBIT_FILE_LIST[@]}"; do
    echo "removing $TARGET_DIR/$file"
    rm -rf "${TARGET_DIR:?}/$file"
done

# get current commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)

cd $TARGET_DIR
git add .
git commit -m "Sync Update - $COMMIT_HASH"

echo ""
echo "======= Sync Update - $COMMIT_HASH ======="
echo "To push to remote, run following command:"
echo ""
echo "  cd $TARGET_DIR && git push origin master"
echo ""
echo "=========================================="
echo ""

# done
