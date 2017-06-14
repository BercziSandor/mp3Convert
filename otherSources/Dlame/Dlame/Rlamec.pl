#! /usr/bin/perl

use Getopt::Std;
use MP3::Info;
use Socket;
use FileHandle;
use POSIX ":sys_wait_h";
use RlameWorkProcess;
use RipNLame;

sub child_handler
{
    # waitpid, rlamechild, und busy loeschen, ALLSONG von inprogress auf done setzen alle daten finden wir aus dem ALLSONGS-Array

    print "Im Childhandler\n";
    while((my $pid=waitpid(-1, &WNOHANG)) > 0)
    {
	my $status = $?;
	print "pid $pid finished error: $status\n";
	foreach my $song (@ALLSONGS)
	{
	    if($song->{'cpu'}->{'rlamechild'}->{'pid'} == $pid)
	    {
		
		print "Childhandle $song->{'cpu'}->{'host'}\n";
		delete($song->{'cpu'}->{'busy'});
		
		vec($rin, fileno($song->{'cpu'}->{'rlamechild'}->{'othersock'}), 1) = 0;
		if($status == 0)
		{
		    $song->{'done'} = 1;
		    my $fullname = "$song->{'workdir'}/track".$song->{'cpu'}->{'rlamechild'}->{'index'}.".cdda.wav";
		    print "Unlinking $fullname\n";
		    unlink($fullname);
		    delete($song->{'cpu'}->{'rlamechild'});
		    # fuer den Fall das wir nur noch auf einen warten
		    my @undonesongs = grep((!defined($_->{'done'}) && !defined($_->{'inprogress'})), @ALLSONGS);
		    print "undone: $#undonesongs\n";
		    if($#undonesongs < 0) # es gibt gar nix mehr zu tun
		    {
			print "Releasing CPU in childhandler $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n";
			syswrite(CPUSOCK, "releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n", length("releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n"));
			$song->{'cpu'}->{'deleteme'} = 1;
			delete($song->{'cpu'});
		    }

		}
		else # da stimmt was nicht, also geben wir die CPU frei und deleten sie besser auch gleich
		{
		    syswrite(CPUSOCK, "releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n", length("releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n"));
		    syswrite(CPUSOCK, "delcpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n", length("delcpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n"));
		    unlink("$opt_d/$song->{'cddbid'}/output$pid.mp3");
		    delete($song->{'cpu'}->{'rlamechild'});
		    $song->{'cpu'}->{'deleteme'} = 1;
		    delete($song->{'cpu'});
		}
#		syswrite(CPUSOCK, "statusupdate $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}|idle||\n", length("$song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}|idle||\n"));
		delete($song->{'inprogress'});
		$SOMEONEDIED = 1;
		last;
	    }
	}
    }
}

sub cleanup
{
    exit(0);
}

sub wait_for_children
{
    my @SONGS;

    $SIG{'CHLD'} = 'IGNORE';
    $SIG{'CLD'} = 'IGNORE';
    print "Now Waiting for children\n";
    foreach my $song (@ALLSONGS)
    {
	next if !defined($song->{'cpu'}->{'rlamechild'});
	push(@SONGS, $song);
    }
    print "$#SONGS\n";
    while($#SONGS > -1)
    {
	my $pid = wait();
	print "$pid\n";
	foreach my $song (@SONGS)
	{
	    if($song->{'cpu'}->{'rlamechild'}->{'pid'} == $pid)
	    {
		print "Childhandle $song->{'cpu'}->{'host'}\n";
		delete($song->{'cpu'}->{'busy'});
		delete($song->{'inprogress'});
		$song->{'done'} = 1;
		my $fullname = "$song->{'workdir'}/track".$song->{'cpu'}->{'rlamechild'}->{'index'}.".cdda.wav";
		print "Unlinking $fullname\n";
		unlink($fullname);
		syswrite(CPUSOCK, "releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n", length("releasecpu $song->{'cpu'}->{'host'}:$song->{'cpu'}->{'port'}\n"));
		$SOMEONEDIED = 1;
		last;
	    }
	}
	@SONGS = grep( $_->{'cpu'}->{'rlamechild'}->{'pid'} != $pid, @SONGS);
	last if $pid == -1;
    }
}

sub parse_cpu
{
    my $line = shift;
    
    my @components = split(/\s+/, $line);
    my @parts = split(/:/, $components[1]);
    my $cpu = {};
    $cpu->{'host'} = $parts[0];
    $cpu->{'port'} = $parts[1];
    return($cpu);
}

sub rip_songs
{
    my $number = shift;
    my $i = 0;

    while(($ALLSONGS[$i]->{'inprogress'}) || ($ALLSONGS[$i]->{'done'}))
    {
	$i++;
    }
    for(my $j=0; $j <= $number; $j++)
    {
	mkdir($ALLSONGS[$i+$j]->{'cddbid'},0775) if(! -d $ALLSONGS[$i+$j]->{'cddbid'});
	chdir($ALLSONGS[$i+$j]->{'cddbid'});
	my $index = $ALLSONGS[$i+$j]->{'index'};
	$index = "0".$index if $index < 10;
	system("cdparanoia -q -d $ALLSONGS[$i+$j]->{'device'} -B $ALLSONGS[$i+$j]->{'index'} 2>/dev/null >/dev/null") 
	    unless -f "track".$index.".cdda.wav";
	chdir("..");
    }
}

sub do_distributed_work
{
    my $infos = shift;
    my $remotehost = shift;
    my $remoteport = shift;
    my $workdir = shift;
    my $mp3dir = shift;
    my ($r, $timeleft, $nfound, $done, @cpus);

    socket(CPUSOCK, PF_INET, SOCK_STREAM, 6)|| die "Can't create socket";
    my $sin = sockaddr_in($remoteport, inet_aton($remotehost));
    connect(CPUSOCK, $sin) || die "Can't connect to CPU-Broker";
    $rin="";
    vec($rin, fileno(CPUSOCK), 1)=1;
    syswrite(CPUSOCK,"getcpu 5\n",9);
    while(!$done)
    {
	($nfound, $timeleft) = select($r=$rin, undef, undef, 3);
	if($timeleft == 0)
	{
	    $done = 1;
	}
	else
	{
	    sysread(CPUSOCK, $line, 8192);
	    if($line =~ /^wait/i)
	    {
		($nfound, $timeleft) = select($r=$rin, undef, undef, undef);
		$line = <CPUSOCK>;
		chomp($line);
		push(@cpus, parse_cpu($line));
	    }
	    else
	    {
		my @lines = split(/\n/m, $line);
		foreach my $l (@lines)
		{
		    push(@cpus, parse_cpu($l));
		}
	    }
	}
    }
    chdir($workdir);
    foreach $i (@$infos)
    {
	setup_dirs($i, $mp3dir);
	$i->{'cddbid'} = $i->{'id'} if(!defined($i->{'cddbid'}));
	mkdir($i->{'cddbid'},0775);
	for(my $j = 0; $j < $i->{'tno'}; $j++)
	{
	    next if (defined($i->{'trackselect'}) && !grep($_ == ($j+1), @{$i->{'trackselect'}}));
	    my $filetitle = create_filetitle($i->{'track'}->[$j]);
	    if(-f "$mp3dir/Interpreten/$i->{'artist'}/$filetitle")
	    {
		setup_link($i, $filetitle, $j+1, $mp3dir);
	    }
	    else
	    {
		my $newhash = {};
		$newhash->{'lied'}   = $i->{'track'}->[$j];
		$newhash->{'device'} = $i->{'dev'};
		$newhash->{'artist'} = $i->{'artist'};
		$newhash->{'title'}  = $i->{'title'};
		$newhash->{'cddbid'} = $i->{'cddbid'};
		$newhash->{'cat'}    = $i->{'cat'};
		$newhash->{'index'}  = $j+1;
		push(@ALLSONGS, $newhash);
	    }
	}
    }
    $done = 0;
    while($#ALLSONGS >= 0)
    {
	my $k=0;
	$done = 0;
	@ALLSONGS = grep(!defined($_->{'done'}), @ALLSONGS);
	print "$#ALLSONGS left\n";
	my @undonesongs = grep(!defined($_->{'inprogress'}), @ALLSONGS);
	my @freecpus = grep(!$_->{'busy'}, @cpus);
	if($#undonesongs < $#freecpus) # wir haben mehr cpus als wir noch brauchen
	{
	    # wenn wir performancedaten haben, erst sortieren
	    my $diff = $#freecpus - $#undonesongs;
	    for(my $k = 0; $k < $diff; $k++)
	    {
		my $cp = pop(@freecpus);
#		@cpus = grep(($_->{'host'} ne $cp->{'host'})&&($_->{'port'} != $cp->{'port'}), @cpus);
		@cpus = grep($_ != $cp, @cpus);
		print "Releasing $cp->{'host'}:$cp->{'port'}\n";
		syswrite(CPUSOCK, "releasecpu $cp->{'host'}:$cp->{'port'}\n", length("releasecpu $cp->{'host'}:$cp->{'port'}\n"));
	    }
	}
	for(my $j=0; $j <= $#freecpus; $j++)
	{
	    while(($ALLSONGS[$j+$k]->{'inprogress'}) || ($ALLSONGS[$j+$k]->{'done'}))
	    {
		$k++;
	    }
	    my $rstatus = "statusupdate $freecpus[$j]->{'host'}:$freecpus[$j]->{'port'}|ripping $ALLSONGS[$k+$j]->{'index'}||\n";
	    syswrite(CPUSOCK, $rstatus, length($rstatus));
	    rip_songs(0);
	    $freecpus[$j]->{'busy'} = 1;

	    chdir($ALLSONGS[$j+$k]->{'cddbid'});
	    my $index = $ALLSONGS[$j+$k]->{'index'};
	    $index = "0$index" if $index < 10;
	    my $fh = FileHandle->new();
	    $fh->open("track$index.cdda.wav")|| die "Could not open track$index.cdda.wav";
	    my ($readfh, $writefh) = FileHandle::pipe;
	    my $rlamechild = RlameWorkProcess->new($fh, $ALLSONGS[$j+$k], create_filetitle($ALLSONGS[$j+$k]->{'lied'}), 
						   $freecpus[$j]->{'host'}, $freecpus[$j]->{'port'}, $mp3dir, $index, $writefh, \*CPUSOCK);
	    $rlamechild->{'othersock'} = $readfh;
	    vec($rin, fileno($readfh), 1) = 1;
	    $rlamechild->do_work();
	    $rlamechild->{'size'} = -s "track$index.cdda.wav";
	    my $status="statusupdate $freecpus[$j]->{'host'}:$freecpus[$j]->{'port'}|$ALLSONGS[$j+$k]->{'title'}|$ALLSONGS[$j+$k]->{'artist'}|$ALLSONGS[$j+$k]->{'index'} $ALLSONGS[$j+$k]->{'lied'}\n";
	    syswrite(CPUSOCK, $status, length($status));
	    $status = "perfupdate $freecpus[$j]->{'host'}:$freecpus[$j]->{'port'}|0|$rlamechild->{'size'}|0\n";
	    syswrite(CPUSOCK, $status, length($status));
	    $freecpus[$j]->{'rlamechild'} = $rlamechild;
	    $freecpus[$j]->{'songinwork'} = $ALLSONGS[$j+$k];
	    $ALLSONGS[$j+$k]->{'cpu'} = $freecpus[$j];
	    $ALLSONGS[$j+$k]->{'workdir'} = "$workdir/$ALLSONGS[$j+$k]->{'cddbid'}";
	    $ALLSONGS[$j+$k]->{'inprogress'} = 1;
	    chdir("..");
	}
	# Hier einen Select, ob uns vielleicht eine weitere CPU geschenkt wird,
	# oder eine weggenommen wird. Wenn der Select mit eintr zurueckkommt,
	# dann ist ein kind gestorben und wir koennen den naechsten Schleifen-
	# durchlauf beginnen

	if($SOMEONEDIED == 1)
	{
	    $SOMEONEDIED = 0;
	    print "Someonedied war 1\n";
	}
	else
	{
	    while(!$done)
	    {
		$nfound = select($r=$rin, undef, undef, undef);
		if($nfound > 0)
		{
		    if(vec($r, fileno(CPUSOCK), 1) == 1)
		    {
			my $buf;
			my $ret = sysread(CPUSOCK, $buf, 8192);
			last if $ret == 0;
			my @lines = split(/\n/, $buf);
			foreach my $line (@lines)
			{
			    if($line =~ /^CPU/)
			    {
				chomp($line);
				print "Got a new CPU\n";
				push(@cpus, parse_cpu($line));
				$done = 1;
			    }
			    elsif($line =~ /^DELCPU/)
			    {
				$line =~ s/^DELCPU (.*)/$1/;
				my $delcpu = {};
				($delcpu->{'host'}, $delcpu->{'port'}) = split(/\|/, $line);
				foreach $cp (@cpus)
				{
				    if(($cp->{'host'} eq $delcpu->{'host'}) && ($cp->{'port'} eq $delcpu->{'port'}))
				    {
					if(defined($cp->{'busy'}))
					{
					    $cp->{'deleteme'} = 1;
					}
					else
					{
					    print "Releasing deleted CPU $cp->{'host'}:$cp->{'port'}\n";
					    syswrite(CPUSOCK, "releasecpu $cp->{'host'}:$cp->{'port'}\n", length("releasecpu $cp->{'host'}:$cp->{'port'}\n"));
					    @cpus = grep($_ != $cp, @cpus);
					}
					last;
				    }
				}
			    }
			}
		    }
		    foreach my $cp (@cpus)
		    {
			next if !defined($cp->{'rlamechild'});
			if(vec($r, fileno($cp->{'rlamechild'}->{'othersock'}), 1) == 1)
			{
			    my $buf;

			    my $now = time();
			    my $ret = sysread($cp->{'rlamechild'}->{'othersock'},$buf, 1024);
			    if($ret > 0)
			    {
				my $rate;
				my @lines = split(/\n/, $buf);
				if($now - $cp->{'rlamechild'}->{'time'} > 0)
				{
				    $rate = ($lines[$#lines] - $cp->{'rlamechild'}->{'bytes'}) / ($now - $cp->{'rlamechild'}->{'time'});
				}
				$cp->{'rlamechild'}->{'bytes'} = $lines[$#lines];
				$cp->{'rlamechild'}->{'time'} = $now;
				$cp->{'rate'} = $rate;
				my $msg = "perfupdate $cp->{'host'}:$cp->{'port'}|$cp->{'rlamechild'}->{'bytes'}|$cp->{'rlamechild'}->{'size'}|$cp->{'rate'}\n";
#				syswrite(CPUSOCK, $msg, length($msg));
#				print "Sending $msg\n";
			    }
			}
		    }
		}
		else
		{
		    $done = 1;
		}
	    }
	}
	if($#undonesongs == -1)
	{
	    wait_for_children();
	    last;
	}
	print "$#cpus cpus left\n";
	foreach my $cp (@cpus)
	{
	    if(!defined($cp->{'busy'}) && defined($cp->{'deleteme'}))
	    {
		print "Releasing deleted CPU $cp->{'host'}:$cp->{'port'}\n";
		syswrite(CPUSOCK, "releasecpu $cp->{'host'}:$cp->{'port'}\n", length("releasecpu $cp->{'host'}:$cp->{'port'}\n")) if(defined($cp->{'deleteme'}) && !$cp->{'busy'});
	    }
	}
	@cpus = grep((defined($_->{'busy'}) || !defined($_->{'deleteme'})), @cpus);
	print "$#cpus cpus left after\n";
    }
    foreach my $cpu (@cpus)
    {
	print "$cpu->{'host'}:$cpu->{'port'}\n";
	syswrite(CPUSOCK, "releasecpu $cpu->{'host'}:$cpu->{'port'}\n", length("releasecpu $cpu->{'host'}:$cpu->{'port'}\n"));
    }
}

sub usage
{
    print "Rlamec.pl -r server:port -d rawfiledir -D datafiledir -m mp3dir <-c cdromdev> <-s songindex> <-h>\n";
    exit(-1);
}

#@DEVICES=qw(/dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3 /dev/sr4);
@DEVICES=qw(/dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3);
#@DEVICES=qw(/dev/sr0 /dev/sr1 /dev/sr2);

my %config;
#$config{'CDDB_HOST'}="cddb.cddb.com";
$config{'CDDB_HOST'}="209.10.41.90";
$config{'CDDB_PORT'}=888;
$config{'input'} = 0;

getopts('r:d:m:D:c:s:');
$opt_d || usage();
$opt_r || usage();
$opt_m || usage();
$opt_D || usage();
$opt_h && usage();

my @tmp = split(/:/, $opt_r);
$remotehost = $tmp[0];
$remoteport = $tmp[1];
$|=1;
@DEVICES = grep($_ eq $opt_c, @DEVICES) if($opt_c);
$pwd=`pwd`;
chomp($pwd);
$infos = get_infos_from_files($opt_D) || get_infos(\%config,\@DEVICES, $opt_D);
chdir($pwd);
$SIG{'CHLD'} = \&child_handler;
$SIG{'CLD'} = \&child_handler;
$SIG{'INT'} = \&cleanup;
$SIG{'TERM'} = \&cleanup;
$SIG{'HUP'} = \&wait_for_children;
if($opt_c)
{
    @$infos = grep($_->{'dev'} eq $opt_c, @$infos);
}
if($opt_s)
{
    foreach $i (@$infos)
    {
	$i->{'trackselect'}->[0] = $opt_s;
    }
}
do_distributed_work($infos, $remotehost, $remoteport, $opt_d, $opt_m);
wait_for_children();
