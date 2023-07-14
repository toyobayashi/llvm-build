#!/usr/bin/env bash

set -ex

__dirname=$(cd dirname $0;pwd)

LLVM_VERSION_MAJOR=16
LLVM_VERSION_MINOR=0
LLVM_VERSION_PATCH=6
CLANG_VERSION=$LLVM_VERSION_MAJOR
LLVM_TAG="llvmorg-$LLVM_VERSION_MAJOR.$LLVM_VERSION_MINOR.$LLVM_VERSION_PATCH"

LLVM_PREFIX=$__dirname/llvm
BUILD_PREFIX=/opt/llvm
WASI_SYSROOT=$LLVM_PREFIX/share/wasi-sysroot

rm -rf $LLVM_PREFIX
mkdir -p $LLVM_PREFIX

REPODIR=$__dirname/.repo

mkdir -p $REPODIR
LLVM_PROJ_DIR=$REPODIR/llvm-project

if [[ ! -d "$LLVM_PROJ_DIR" ]]; then
  git clone --depth=1 --branch $LLVM_TAG https://github.com/llvm/llvm-project.git $LLVM_PROJ_DIR
  rm -rf $LLVM_PROJ_DIR/.git
fi

if [[ ! -d "$REPODIR/wasi-libc" ]]; then
  git clone --depth=1 --recursive https://github.com/WebAssembly/wasi-libc.git $REPODIR/wasi-libc
  rm -rf $REPODIR/wasi-libc/.git
fi


LLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi"
LLVM_ADDITIONAL_CMAKE_FLAGS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  LLVM_ADDITIONAL_CMAKE_FLAGS="$LLVM_ADDITIONAL_CMAKE_FLAGS \
-DDEFAULT_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64 \
-DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
else
  LLVM_ENABLE_RUNTIMES="$LLVM_ENABLE_RUNTIMES;libc"
fi

# -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-apple-darwin \
mkdir -p $__dirname/build/llvm
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
  -DLLVM_HAVE_LIBXAR=OFF \
  -DCMAKE_INSTALL_PREFIX=$LLVM_PREFIX \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_TARGETS_TO_BUILD="WebAssembly;AArch64;ARM;X86" \
  -DLLVM_ENABLE_PROJECTS="lld;clang;clang-tools-extra;lldb" \
  -DLLVM_ENABLE_RUNTIMES=$LLVM_ENABLE_RUNTIMES \
  -DLLVM_INSTALL_BINUTILS_SYMLINKS=TRUE \
  -DLLVM_ENABLE_LIBXML2=OFF \
  $LLVM_ADDITIONAL_CMAKE_FLAGS \
  -H"$LLVM_PROJ_DIR/llvm" -B"$__dirname/build/llvm"

cmake --build $__dirname/build/llvm
cmake --install $__dirname/build/llvm --prefix $LLVM_PREFIX

DIRECTORY=$LLVM_PREFIX/bin
if [[ "$OSTYPE" == "darwin"* ]]; then
  EXECUTABLES=$(find ${DIRECTORY} -type f -perm +111)
else
  EXECUTABLES=$(find ${DIRECTORY} -type f -executable)
fi

for e in ${EXECUTABLES}; do
  echo "Stripping symbols: ${e}"
  strip ${e} || echo "Failed to strip symbols for ${e}; continuing on."
done

mkdir -p $WASI_SYSROOT
make -C $REPODIR/wasi-libc \
    CC=$LLVM_PREFIX/bin/clang \
		AR=$LLVM_PREFIX/bin/llvm-ar \
		NM=$LLVM_PREFIX/bin/llvm-nm \
		SYSROOT=$WASI_SYSROOT
make -C $REPODIR/wasi-libc \
    CC=$LLVM_PREFIX/bin/clang \
		AR=$LLVM_PREFIX/bin/llvm-ar \
		NM=$LLVM_PREFIX/bin/llvm-nm \
		SYSROOT=$WASI_SYSROOT \
    THREAD_MODEL=posix

mkdir -p $LLVM_PREFIX/share/cmake

sh -c "cat > $LLVM_PREFIX/share/cmake/wasi32.cmake << 'EOL'
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME WASM)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32)

if(WIN32)
	set(WASM_HOST_EXE_SUFFIX \".exe\")
else()
	set(WASM_HOST_EXE_SUFFIX \"\")
endif()

set(CMAKE_C_COMPILER \${LLVM_PREFIX}/bin/clang\${WASM_HOST_EXE_SUFFIX})
set(CMAKE_CXX_COMPILER \${LLVM_PREFIX}/bin/clang++\${WASM_HOST_EXE_SUFFIX})
set(CMAKE_ASM_COMPILER \${LLVM_PREFIX}/bin/clang\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_AR \${LLVM_PREFIX}/bin/llvm-ar\${WASM_HOST_EXE_SUFFIX})
set(CMAKE_RANLIB \${LLVM_PREFIX}/bin/llvm-ranlib\${WASM_HOST_EXE_SUFFIX})
set(CMAKE_C_COMPILER_TARGET \${triple})
set(CMAKE_CXX_COMPILER_TARGET \${triple})
set(CMAKE_ASM_COMPILER_TARGET \${triple})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_CXX_COMPILER_WORKS 1)
EOL"

sh -c "cat > $LLVM_PREFIX/share/cmake/wasi-sdk.cmake << 'EOL'
# Cmake toolchain description file for the Makefile

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME WASI)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-wasi)

if(WIN32)
	set(WASI_HOST_EXE_SUFFIX \".exe\")
else()
	set(WASI_HOST_EXE_SUFFIX \"\")
endif()

set(CMAKE_C_COMPILER \${WASI_SDK_PREFIX}/bin/clang\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_CXX_COMPILER \${WASI_SDK_PREFIX}/bin/clang++\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_ASM_COMPILER \${WASI_SDK_PREFIX}/bin/clang\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_AR \${WASI_SDK_PREFIX}/bin/llvm-ar\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_RANLIB \${WASI_SDK_PREFIX}/bin/llvm-ranlib\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_C_COMPILER_TARGET \${triple})
set(CMAKE_CXX_COMPILER_TARGET \${triple})
set(CMAKE_ASM_COMPILER_TARGET \${triple})
set(CMAKE_SYSROOT \${WASI_SDK_PREFIX}/share/wasi-sysroot)

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOL"

sh -c "cat > $LLVM_PREFIX/share/cmake/wasi-sdk-pthread.cmake << 'EOL'
# Cmake toolchain description file for the Makefile

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME WASI)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-wasi-threads)
set(CMAKE_C_FLAGS \"\${CMAKE_C_FLAGS} -pthread\")
set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -pthread\")
# wasi-threads requires --import-memory.
# wasi requires --export-memory.
# (--export-memory is implicit unless --import-memory is given)
set(CMAKE_EXE_LINKER_FLAGS \"\${CMAKE_EXE_LINKER_FLAGS} -Wl,--import-memory\")
set(CMAKE_EXE_LINKER_FLAGS \"\${CMAKE_EXE_LINKER_FLAGS} -Wl,--export-memory\")

if(WIN32)
	set(WASI_HOST_EXE_SUFFIX \".exe\")
else()
	set(WASI_HOST_EXE_SUFFIX \"\")
endif()

set(CMAKE_C_COMPILER \${WASI_SDK_PREFIX}/bin/clang\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_CXX_COMPILER \${WASI_SDK_PREFIX}/bin/clang++\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_ASM_COMPILER \${WASI_SDK_PREFIX}/bin/clang\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_AR \${WASI_SDK_PREFIX}/bin/llvm-ar\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_RANLIB \${WASI_SDK_PREFIX}/bin/llvm-ranlib\${WASI_HOST_EXE_SUFFIX})
set(CMAKE_C_COMPILER_TARGET \${triple})
set(CMAKE_CXX_COMPILER_TARGET \${triple})
set(CMAKE_ASM_COMPILER_TARGET \${triple})
set(CMAKE_SYSROOT \${WASI_SDK_PREFIX}/share/wasi-sysroot)

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOL"

mkdir -p $__dirname/build/compiler_rt
CMAKE_MODULE_PATH=$LLVM_PROJ_DIR/cmake

mkdir -p $CMAKE_MODULE_PATH/Platform
echo "set(WASI 1)" > $CMAKE_MODULE_PATH/Platform/WASI.cmake

cmake -G Ninja \
		-DCMAKE_SYSROOT=$WASI_SYSROOT \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_AR=$LLVM_PREFIX/bin/ar \
		-DCMAKE_MODULE_PATH=$CMAKE_MODULE_PATH \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_TOOLCHAIN_FILE=$LLVM_PREFIX/share/cmake/wasi-sdk.cmake \
		-DCOMPILER_RT_BAREMETAL_BUILD=On \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-DCOMPILER_RT_HAS_FPIC_FLAG=OFF \
		-DCOMPILER_RT_ENABLE_IOS=OFF \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=On \
		-DWASI_SDK_PREFIX=$LLVM_PREFIX \
		-DLLVM_CONFIG_PATH=$LLVM_PREFIX/bin/llvm-config \
		-DCOMPILER_RT_OS_DIR=wasi \
		-DCMAKE_INSTALL_PREFIX=$LLVM_PREFIX/lib/clang/$CLANG_VERSION \
		-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -H"$LLVM_PROJ_DIR/compiler-rt/lib/builtins" -B"$__dirname/build/compiler_rt"
cmake --build $__dirname/build/compiler_rt
cmake --install $__dirname/build/compiler_rt --prefix $LLVM_PREFIX/lib/clang/$CLANG_VERSION

get_libcxx_cmake_flags () {
	local args="-DCMAKE_C_COMPILER_WORKS=ON \
-DCMAKE_CXX_COMPILER_WORKS=ON \
-DCMAKE_AR=$LLVM_PREFIX/bin/ar \
-DCMAKE_MODULE_PATH=$CMAKE_MODULE_PATH \
-DCMAKE_TOOLCHAIN_FILE=$LLVM_PREFIX/share/cmake/wasi-sdk.cmake \
-DCMAKE_STAGING_PREFIX=$WASI_SYSROOT \
-DLLVM_CONFIG_PATH=$LLVM_PREFIX/bin/llvm-config \
-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
-DCXX_SUPPORTS_CXX11=ON \
-DLIBCXX_ENABLE_THREADS:BOOL=$1 \
-DLIBCXX_HAS_PTHREAD_API:BOOL=$1 \
-DLIBCXX_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
-DLIBCXX_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
-DLIBCXX_HAS_WIN32_THREAD_API:BOOL=OFF \
-DLLVM_COMPILER_CHECKED=ON \
-DCMAKE_BUILD_TYPE=RelWithDebugInfo \
-DLIBCXX_ENABLE_SHARED:BOOL=OFF \
-DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY:BOOL=OFF \
-DLIBCXX_ENABLE_EXCEPTIONS:BOOL=OFF \
-DLIBCXX_ENABLE_FILESYSTEM:BOOL=OFF \
-DLIBCXX_CXX_ABI=libcxxabi \
-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$LLVM_PROJ_DIR/libcxxabi/include \
-DLIBCXX_HAS_MUSL_LIBC:BOOL=ON \
-DLIBCXX_ABI_VERSION=2 \
-DLIBCXXABI_ENABLE_EXCEPTIONS:BOOL=OFF \
-DLIBCXXABI_ENABLE_SHARED:BOOL=OFF \
-DLIBCXXABI_SILENT_TERMINATE:BOOL=ON \
-DLIBCXXABI_ENABLE_THREADS:BOOL=$1 \
-DLIBCXXABI_HAS_PTHREAD_API:BOOL=$1 \
-DLIBCXXABI_HAS_EXTERNAL_THREAD_API:BOOL=OFF \
-DLIBCXXABI_BUILD_EXTERNAL_THREAD_LIBRARY:BOOL=OFF \
-DLIBCXXABI_HAS_WIN32_THREAD_API:BOOL=OFF \
-DLIBCXXABI_ENABLE_PIC:BOOL=OFF \
-DWASI_SDK_PREFIX=$LLVM_PREFIX \
-DUNIX:BOOL=ON \
--debug-trycompile"
  echo $args
}

mkdir -p $__dirname/build/libcxx
cmake -G Ninja $(get_libcxx_cmake_flags OFF) \
		-DCMAKE_SYSROOT=$WASI_SYSROOT \
		-DCMAKE_CXX_FLAGS="-fno-exceptions" \
		-DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasi \
		-DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasi \
		-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
		-H"$LLVM_PROJ_DIR/runtimes" -B"$__dirname/build/libcxx"
cmake --build $__dirname/build/libcxx

mkdir -p $__dirname/build/libcxx-threads
cmake -G Ninja $(get_libcxx_cmake_flags ON) \
		-DCMAKE_SYSROOT=$WASI_SYSROOT \
    -DCMAKE_C_FLAGS="-pthread" \
		-DCMAKE_CXX_FLAGS="-pthread -fno-exceptions" \
		-DLIBCXX_LIBDIR_SUFFIX=/wasm32-wasi-threads \
		-DLIBCXXABI_LIBDIR_SUFFIX=/wasm32-wasi-threads \
		-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
		-H"$LLVM_PROJ_DIR/runtimes" -B"$__dirname/build/libcxx-threads"
cmake --build $__dirname/build/libcxx-threads
cmake --install $__dirname/build/libcxx --prefix $WASI_SYSROOT
cmake --install $__dirname/build/libcxx-threads --prefix $WASI_SYSROOT

# rm -rf $__dirname/build
# rm -rf $REPODIR
mv $LLVM_PREFIX $BUILD_PREFIX
