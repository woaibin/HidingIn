#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Users/binxiaokang/QT6/6.8.0/macos/libexec/rcc --no-zstd --name resources --output /Users/binxiaokang/Desktop/HidingIn/qrc_resources.cpp /Users/binxiaokang/Desktop/HidingIn/resources/resources.qrc
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Users/binxiaokang/QT6/6.8.0/macos/libexec/rcc --no-zstd --name resources --output /Users/binxiaokang/Desktop/HidingIn/qrc_resources.cpp /Users/binxiaokang/Desktop/HidingIn/resources/resources.qrc
fi
if test "$CONFIGURATION" = "MinSizeRel"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Users/binxiaokang/QT6/6.8.0/macos/libexec/rcc --no-zstd --name resources --output /Users/binxiaokang/Desktop/HidingIn/qrc_resources.cpp /Users/binxiaokang/Desktop/HidingIn/resources/resources.qrc
fi
if test "$CONFIGURATION" = "RelWithDebInfo"; then :
  cd /Users/binxiaokang/Desktop/HidingIn
  /Users/binxiaokang/QT6/6.8.0/macos/libexec/rcc --no-zstd --name resources --output /Users/binxiaokang/Desktop/HidingIn/qrc_resources.cpp /Users/binxiaokang/Desktop/HidingIn/resources/resources.qrc
fi

