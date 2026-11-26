#!/bin/bash
# Headless RDP session automation for Anthem (SG user)
export DISPLAY=:99
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
XPID=$!
sleep 2

xfreerdp3 /v:10.48.191.46 /u:SG /p:'UmbracoIsTheBest!' /cert:ignore \
  /size:1280x800 /shell:cmd.exe /drive:share,/home/shrdx/Documents/Anthem \
  /log-level:WARN >/home/shrdx/Documents/Anthem/rdp_sg.log 2>&1 &
RPID=$!

echo "waiting for window..."
for i in $(seq 1 40); do
  WID=$(xdotool search --onlyvisible --name "FreeRDP" 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  sleep 1
done
if [ -z "$WID" ]; then
  WID=$(xdotool search --onlyvisible --class "xfreerdp" 2>/dev/null | head -1)
fi
echo "WID=$WID"
[ -z "$WID" ] && { echo "NO WINDOW"; kill $RPID $XPID; exit 1; }

xdotool windowactivate --sync "$WID" 2>/dev/null
sleep 8

shot() { import -window root "/home/shrdx/Documents/Anthem/shot_$1.png" 2>/dev/null; }

type_cmd() {
  xdotool type --window "$WID" --delay 15 "$1"
  xdotool key --window "$WID" Return
  sleep 2
}

shot 01_start
type_cmd 'whoami'
type_cmd 'hostname'
type_cmd 'dir /a C:\Users\SG\Desktop'
type_cmd 'dir /a C:\Users\SG'
type_cmd 'type C:\Users\SG\Desktop\user.txt'
shot 02_user
type_cmd 'dir /a /s C:\Users\SG\*.txt'
shot 03_search
type_cmd 'copy C:\Users\SG\Desktop\user.txt \\tsclient\share\user.txt'
type_cmd 'dir \\tsclient\share'
shot 04_copy

sleep 3
shot 05_end
kill $RPID 2>/dev/null
sleep 1
kill $XPID 2>/dev/null
echo done
