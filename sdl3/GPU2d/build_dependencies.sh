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



## Clean-up
popd