#!/bin/zsh
# Relaunch the installed debug build with arguments and take a screenshot after a delay.
# Usage: scripts/shoot.sh <output.png> <delay seconds> [launch arguments...]
OUT=$1; DELAY=$2; shift 2
xcrun simctl terminate ${SIM:-booted} com.tomblackburn.shiftline 2>/dev/null
xcrun simctl launch ${SIM:-booted} com.tomblackburn.shiftline "$@" > /dev/null
sleep $DELAY
xcrun simctl io ${SIM:-booted} screenshot "$OUT" > /dev/null 2>&1
sips -r 270 "$OUT" > /dev/null 2>&1
sips -Z 874 "$OUT" > /dev/null 2>&1
