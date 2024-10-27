#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Applications/CMake.app/Contents/bin/cmake -E cmake_autogen /Users/binxiaokang/Desktop/HidingIn/CMakeFiles/HidingIn_autogen.dir/AutogenInfo.json Debug
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Applications/CMake.app/Contents/bin/cmake -E cmake_autogen /Users/binxiaokang/Desktop/HidingIn/CMakeFiles/HidingIn_autogen.dir/AutogenInfo.json Release
fi
if test "$CONFIGURATION" = "MinSizeRel"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Applications/CMake.app/Contents/bin/cmake -E cmake_autogen /Users/binxiaokang/Desktop/HidingIn/CMakeFiles/HidingIn_autogen.dir/AutogenInfo.json MinSizeRel
fi
if test "$CONFIGURATION" = "RelWithDebInfo"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Applications/CMake.app/Contents/bin/cmake -E cmake_autogen /Users/binxiaokang/Desktop/HidingIn/CMakeFiles/HidingIn_autogen.dir/AutogenInfo.json RelWithDebInfo
fi

