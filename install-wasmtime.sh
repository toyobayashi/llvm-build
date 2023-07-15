#!/usr/bin/env bash

set -ex

WASMTIME_VERSION=v10.0.1

if [[ "$OSTYPE" == "darwin"* ]]; then
	if [[ `uname -m` == "arm"* ]]; then
		WASMTIME_NAME=wasmtime-$WASMTIME_VERSION-aarch64-macos
	else
		WASMTIME_NAME=wasmtime-$WASMTIME_VERSION-x86_64-macos
	fi
else
  if [[ `uname -m` == "aarch64" ]]; then
		WASMTIME_NAME=wasmtime-$WASMTIME_VERSION-aarch64-linux
	else
		WASMTIME_NAME=wasmtime-$WASMTIME_VERSION-x86_64-linux
	fi
fi

curl -sSOL https://github.com/bytecodealliance/wasmtime/releases/download/$WASMTIME_VERSION/$WASMTIME_NAME.tar.xz
tar -xvf $WASMTIME_NAME.tar.xz
rm -rf $WASMTIME_NAME.tar.xz
mv -f $WASMTIME_NAME/wasmtime /usr/local/bin
rm -rf $WASMTIME_NAME
