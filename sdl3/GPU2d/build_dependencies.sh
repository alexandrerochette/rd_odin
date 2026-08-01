#!/bin/sh

mkdir -p .dependencies
mkdir -p .dependencies/lib

pushd .dependencies

## 
## YOGA STATIC LIBRARY
##
git clone https://github.com/react/yoga.git 
pushd yoga/
./unit_tests Release
cp tests/build/yoga/*.a  ../lib
popd


## 
## SLANG Shader Compiler
##
mkdir -p ./slang/
#wget https://github.com/shader-slang/slang/releases/download/v2026.14/slang-2026.14-macos-aarch64.zip
#unzip slang-2026.14-macos-aarch64.zip -d ./slang/
mkdir ../.generated
mkdir ../canvas/.generated
popd



## Clean-up
popd