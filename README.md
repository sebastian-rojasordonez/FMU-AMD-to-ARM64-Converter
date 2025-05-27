# 🚀 FMU to ARM64 Converter

Welcome! 🎉 This repository contains everything you need to **convert** FMUs generated on an x86_64 machine with OpenModelica into FMUs compiled for **ARM64** (e.g., NVIDIA Orin). This guide is written for beginners—no prior experience required! 😎

## 📋 Repository Structure

```
├── models/                          # Original .fmu files exported from OMEdit
├── aarch64-toolchain.cmake         # CMake toolchain configuration for ARM64
├── convert_fmus.sh                 # Automated script to convert all FMUs
├── README.md                       # This guide
└── work/                           # Temporary directories and final ARM64 FMUs
```

## ⚙️ Prerequisites (x86_64 Host)

Install required packages on Ubuntu 22.04+:

```bash
sudo apt update
sudo apt install -y \
  gcc-aarch64-linux-gnu \
  g++-aarch64-linux-gnu \
  cmake \
  make \
  unzip \
  zip
```

> 💡 **Tip**: `gcc-aarch64-linux-gnu` and `g++-aarch64-linux-gnu` are the cross-compilers for ARM64.

## 🔧 Step 1: Export FMUs from OMEdit (Source-only)

1. **Open OMEdit**, load your Modelica file (e.g., `MyModel.mo`).
2. Click **Simulation → Check Model** and fix any errors.
3. Select **File → Export → FMU** and configure:
   - **FMU Version**: 2.0
   - **FMU Type**: Co-Simulation (or Model Exchange)
   - **Include Source Code**: ☑️
   - **Compile FMU**: ⬜
4. Click **OK**. A file named `MyModel.fmu` is created with a `sources/` folder inside.

> ✅ Exporting with **source-only** lets you recompile the code on any target platform.

## 🛠️ Step 2: Prepare the Toolchain File

Create or verify `aarch64-toolchain.cmake` in the repo root. It should contain:

```cmake
set(CMAKE_SYSTEM_NAME        Linux)
set(CMAKE_SYSTEM_PROCESSOR   aarch64)

set(CMAKE_C_COMPILER         aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER       aarch64-linux-gnu-g++)

# Prevent mixing host and target libraries
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

## 📝 Step 3: Disable the `install()` Block in CMakeLists.txt

Before building, comment out the section in **every** `*_tmp/sources/CMakeLists.txt` that uses `install(TARGETS ... RUNTIME_DEPENDENCIES)`. This avoids cross-compilation errors.

Open the file and find:
```cmake
# Install target
if(RUNTIME_DEPENDENCIES_LEVEL STREQUAL "all")
  install(TARGETS ${FMU_NAME_HASH}
    RUNTIME_DEPENDENCIES
      DIRECTORIES ...
    ...
  )
elseif(RUNTIME_DEPENDENCIES_LEVEL STREQUAL "modelica")
  ...
else()
  install(TARGETS ${FMU_NAME_HASH}
    ARCHIVE DESTINATION ...
    LIBRARY DESTINATION ...
    RUNTIME DESTINATION ...
  )
endif()
```
Comment the entire block by adding `#` at the start of each line.

## 🤖 Step 4: Automated Conversion Script

Use the provided `convert_fmus.sh` to process all FMUs in `models/`:

```bash
chmod +x convert_fmus.sh
./convert_fmus.sh
```

This script does:
1. **Unzip** each `models/*.fmu` into `work/<Model>_tmp/`.
2. **Build** the ARM64 `.so` in `sources/build/`.
3. **Duplicate** the `.so` into:
   - `binaries/aarch64-linux-gnu/`
   - `binaries/linux64/` ← some tools expect `linux64`.
4. **Repackage** as `work/<Model>_ARM64.fmu`.

## 📦 Step 5: Conversion Script (`convert_fmus.sh`)
```bash
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
  cmake .. \
    -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE=../../../aarch64-toolchain.cmake \
    -DCMAKE_SKIP_INSTALL_RULES=TRUE
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
```

## 🎉 Step 6: Deploy on ARM64 Device

1. **Copy** to target:
```bash
scp work/*_ARM64.fmu user@orin:/home/user/fmus/
```

2. **Test on device**:
```bash
pip3 install fmpy
python3 -c "from fmpy import simulate_fmu; res = simulate_fmu('MyModel_ARM64.fmu', start_time=0, stop_time=1); print(res.tail(1))"
```

👍 **Done!** You now have ARM64-compatible FMUs ready for GitHub or deployment.