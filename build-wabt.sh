#!/usr/bin/env bash

set -ex

__dirname=$(cd dirname $0;pwd)

WABT_VERSION_MAJOR=1
WABT_VERSION_MINOR=0
WABT_VERSION_PATCH=33
WABT_TAG="$WABT_VERSION_MAJOR.$WABT_VERSION_MINOR.$WABT_VERSION_PATCH"

WABT_PREFIX=$__dirname/wabt
BUILD_PREFIX=/opt/wabt

rm -rf $WABT_PREFIX
mkdir -p $WABT_PREFIX

REPODIR=$__dirname/.repo

mkdir -p $REPODIR
WABT_PROJ_DIR=$REPODIR/wabt

if [[ ! -d "$WABT_PROJ_DIR" ]]; then
  git clone --depth=1 --recursive --branch $WABT_TAG https://github.com/WebAssembly/wabt $WABT_PROJ_DIR
  rm -rf $WABT_PROJ_DIR/.git
fi

WABT_ADDITIONAL_CMAKE_FLAGS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  WABT_ADDITIONAL_CMAKE_FLAGS="$WABT_ADDITIONAL_CMAKE_FLAGS \
-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64 \
-DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
fi

mkdir -p $__dirname/build/wabt
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF \
  -DUSE_INTERNAL_SHA256=ON \
  -DCMAKE_INSTALL_PREFIX=$WABT_PREFIX \
  $WABT_ADDITIONAL_CMAKE_FLAGS \
  -H"$WABT_PROJ_DIR" -B"$__dirname/build/wabt"

cmake --build $__dirname/build/wabt
cmake --install $__dirname/build/wabt --prefix $WABT_PREFIX

# rm -rf $__dirname/build
# rm -rf $REPODIR
mv $WABT_PREFIX $BUILD_PREFIX
