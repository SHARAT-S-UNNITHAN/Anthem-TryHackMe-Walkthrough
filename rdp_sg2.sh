#!/bin/bash
export DISPLAY=:99
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
XPID=$!
sleep 2

xfreerdp3 /v:10.48.191.46 /u:SG /p:'UmbracoIsTheBest!' /cert:ignore \
  /size:1280x800 /drive:share,/home/shrdx/Documents/Anthem \
  /log-level:ERROR >/home/shrdx/Documents/Anthem/rdp_sg2.log 2>&1 &
RPID=$!

for i in $(seq 1 60); do
  WID=$(xdotool search --onlyvisible --name "FreeRDP" 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  sleep 1
done
echo "WID=$WID"
sleep 20

shot() { import -window root "/home/shrdx/Documents/Anthem/s2_$1.png" 2>/dev/null; }
focus() { xdotool windowactivate "$WID" 2>/dev/null; xdotool windowfocus "$WID" 2>/dev/null; sleep 1; }
typ() { xdotool type --clearmodifiers --delay 25 "$1" 2>/dev/null; sleep 1; }
key() { xdotool key --clearmodifiers "$1" 2>/dev/null; sleep 1; }

focus
shot 01_desktop
key super+r
sleep 3
shot 02_run
typ 'cmd.exe'
key Return
sleep 5
shot 03_cmd

# Now type commands into the cmd window
typ 'whoami > \\tsclient\share\whoami.txt'
key Return
sleep 2
typ 'hostname > \\tsclient\share\hostname.txt'
key Return
sleep 2
typ 'dir /a C:\Users\SG\Desktop > \\tsclient\share\desktop.txt'
key Return
sleep 2
typ 'type C:\Users\SG\Desktop\user.txt > \\tsclient\share\user.txt'
key Return
sleep 2
typ 'dir /a /s C:\Users\SG\*.txt > \\tsclient\share\search.txt'
key Return
sleep 3
shot 04_done
typ 'dir \\tsclient\share'
key Return
sleep 2
shot 05_share

kill $RPID 2>/dev/null
sleep 1
kill $XPID 2>/dev/null
echo done
