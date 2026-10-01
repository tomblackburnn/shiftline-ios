#!/bin/zsh
# Captures README screenshots from the debug build (requires scripts/install.sh first).
OUT=${1:-docs/screenshots}
SIM=${SIM:-booted}
shot() {
    local name=$1 delay=$2
    shift 2
    xcrun simctl terminate $SIM com.tomblackburn.shiftline 2>/dev/null
    xcrun simctl launch $SIM com.tomblackburn.shiftline "$@" > /dev/null
    sleep $delay
    xcrun simctl io $SIM screenshot "$OUT/$name.png" > /dev/null 2>&1
    sips -r 270 "$OUT/$name.png" > /dev/null
    sips -Z 1200 "$OUT/$name.png" > /dev/null
}
shot circuit 16 -debugProfile -debugRace velocity-gp race -debugAutopilot
shot street-night 18 -debugRace neon-downtown race -debugAutopilot -debugTime night
shot mountain-rain 14 -debugRace ridge-downhill race -debugAutopilot -debugWeather rain
shot drift 12 -debugRace harbour-yard drift -debugAutopilot -debugTime sunset
shot drag 9 -debugRace kestrel-quarter drag -debugAutopilot -debugTime sunset
shot drag-results 30 -debugRace kestrel-quarter drag -debugAutopilot
shot main-menu 3
