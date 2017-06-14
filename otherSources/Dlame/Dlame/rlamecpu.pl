#! /usr/local/bin/perl
# $Id: rlamecpu.pl,v 1.2 2000/08/05 20:43:15 elwood Exp $

system("/usr/local/bin/lame -v -S --nohist - /var/tmp/output.mp3 2>1 > /dev/null");

# Fertig und jetzt das mp3 zurueck
open(MP3, "/var/tmp/output.mp3");
while(($bytes_read = sysread(MP3, $buf, 1448)) > 0)
{
    my $sent = syswrite(STDOUT, $buf, $bytes_read);
    last if $sent == 0;
}
close(MP3);
close(STDOUT);
unlink("/var/tmp/output.mp3");
