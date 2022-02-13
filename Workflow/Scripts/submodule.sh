#!/bin/bash

set -e

cd "$(dirname "$0")"
cd ../../

git submodule update --init --recursive --remote
