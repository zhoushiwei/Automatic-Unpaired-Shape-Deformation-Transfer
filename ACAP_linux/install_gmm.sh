#!/bin/bash
if [ ! -d "./ACAP-build" ]; then
  mkdir ./ACAP-build
fi
cd ./ACAP-build

if [ ! -d "gmm-build" ]; then
  mkdir gmm-build
fi
cd gmm-build

../../3rd/gmm/configure --prefix=$(pwd)/install-custom
make install
