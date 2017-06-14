#! /bin/sh
/usr/local/bin/lame -v -S --nohist - /var/tmp/output.mp3 2>/dev/null > /dev/null
/bin/cat /var/tmp/output.mp3 
rm /var/tmp/output.mp3
