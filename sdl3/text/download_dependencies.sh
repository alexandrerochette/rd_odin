#!/bin/sh

mkdir -p ./.dependencies/slang/
cd ./.dependencies/
wget https://github.com/shader-slang/slang/releases/download/v2026.14/slang-2026.14-macos-aarch64.zip
unzip slang-2026.14-macos-aarch64.zip -d ./slang/