#!/usr/bin/env bash
set -e

# 1) Unzip FMUs
mkdir -p work
for fmu in models/*.fmu; do
  name=$(basename "$fmu" .fmu)
  echo "Unzipping $name"
  rm -rf "work/${name}_tmp"
  mkdir -p "work/${name}_tmp"
  unzip -q "$fmu" -d "work/${name}_tmp"
done

# 2) Compile each
for tmp in work/*_tmp; do
  name=$(basename "$tmp" _tmp)
  echo "Building $name for ARM64"
  pushd "$tmp/sources"
  rm -rf build && mkdir build && cd build
  cmake ..     -G "Unix Makefiles"     -DCMAKE_TOOLCHAIN_FILE=../../../aarch64-toolchain.cmake     -DCMAKE_SKIP_INSTALL_RULES=TRUE
  make -j$(nproc)
  popd
  mkdir -p "${tmp}/binaries/aarch64-linux-gnu"
  mkdir -p "${tmp}/binaries/linux64"
  cp "${tmp}/sources/build/"*.so "${tmp}/binaries/aarch64-linux-gnu/${name}.so"
  cp "${tmp}/sources/build/"*.so "${tmp}/binaries/linux64/${name}.so"

  # 4) Package FMU
  pushd "$(dirname "$tmp")"
  mkdir -p "${name}_ARM64"
  cp -r "${name}_tmp/modelDescription.xml" "${name}_ARM64/"
  cp -r "${name}_tmp/binaries"      "${name}_ARM64/"
  cp -r "${name}_tmp/resources"     "${name}_ARM64/"
  (cd "${name}_ARM64" && zip -qr "../${name}_ARM64.fmu" .)
  popd
done

echo "All FMUs converted!"