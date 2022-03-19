#!/bin/bash

set -ex

cd "$(dirname "$0")"
WORKING_ROOT="$(pwd)"
cd "$WORKING_ROOT"

DATE=$(date +%Y%m%d)

# make sure .build exists
mkdir -p .build || true

cd .build

# clone from https://github.com/Innei/rayon-terminal if not exists
GIT_URL="https://github.com/Innei/rayon-terminal"
GIT_PATH="RayonTerminal"

if [ ! -d "$GIT_PATH" ]; then
    git clone "$GIT_URL" "$GIT_PATH"
fi

cd "$GIT_PATH"
git clean -fdx
git reset --hard
git pull

pnpm install
pnpm run build

#check if dist exists
if [ ! -d "dist" ]; then
    echo "dist not found"
    exit 1
fi

cd dist
DIST_PATH="$(pwd)"

cd "$WORKING_ROOT"
rm -rf ./Sources/XTerminalUI/xterm
cp -r "$DIST_PATH" ./Sources/XTerminalUI/xterm

# git switch to main if not
git checkout main
git add .
git commit -m "Update Xterm $DATE"

echo "success!"
