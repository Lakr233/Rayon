#!/bin/bash

set -e

cd "$(dirname "$0")"
cd ../../

# check if .root file exists
if [ ! -f .root ]; then
    echo "malformed project structure, missing .root file"
    exit 1
fi

WORKING_ROOT=$(pwd)

cd "$WORKING_ROOT/Application"
swiftformat . --swiftversion 6

cd "$WORKING_ROOT/Foundation"
swiftformat . --swiftversion 6

cd "$WORKING_ROOT"

echo "done fmt"