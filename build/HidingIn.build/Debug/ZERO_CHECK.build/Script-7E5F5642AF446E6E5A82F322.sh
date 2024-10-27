#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  make -f /Users/binxiaokang/Desktop/HidingIn/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  make -f /Users/binxiaokang/Desktop/HidingIn/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "MinSizeRel"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  make -f /Users/binxiaokang/Desktop/HidingIn/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "RelWithDebInfo"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  make -f /Users/binxiaokang/Desktop/HidingIn/CMakeScripts/ReRunCMake.make
fi

