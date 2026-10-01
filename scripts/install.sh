#!/bin/zsh
# Installs the most recent debug build on the booted simulator (or $SIM).
APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/Shiftline-*/Build/Products/Debug-iphonesimulator/Shiftline.app | head -1)
xcrun simctl install ${SIM:-booted} "$APP"
