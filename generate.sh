#!/bin/bash

export PYTHON_EXECUTABLE="/Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11"
# Create and enter the build directory.
rm -rf build
mkdir build
cd build

# To perform a MacOS build using an ARM64 CEF binary distribution:
cmake -G "Xcode" -DPROJECT_ARCH="arm64" ..
# Then, open build\cef.xcodeproj in Xcode and select Product > Build.

