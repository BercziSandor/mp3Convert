#! /usr/bin/perl
# $Id: Rlamed.pl,v 1.7 2000/08/28 18:28:35 elwood Exp $

use FileHandle;
use Socket;
use Getopt::Std;

sub send_status_msgs
{
    my $msg = shift;

    foreach my $fh (@STATUSRECEIVERS)
    {
	syswrite($fh, $msg, length($msg)) || die "Could not send message to receiver";
    }    
}

sub read_config
{
    my $conffile = shift;
    
    my $conf = {};
    open(CONF, $conffile) || die "Could not open conffile $conffile";
    while(<CONF>)
    {
	next if /^#/;
	next if /^$/;
	my @parts = split(/\s*=\s*/);
	chomp($parts[1]);
	if(/^CPU/)
	{
	    my @hostport = split(/:/,$parts[1]);
	    my $cpu = {};
	    $cpu->{'host'} = $hostport[0];
	    $cpu->{'port'} = $hostport[1];
	    push(@{$conf->{'cpus'}}, $cpu);
	}
	elsif(/^PORT/)
	{
	    $conf->{'port'} = $parts[1];
	}
	elsif(/^UDSPATH/)
	{
	    $conf->{'udspath'} = $parts[1];
	}
	else
	{
	    print "Error unknown directive $parts[0]\n";
	}
    }
    return($conf);
}

sub realloc
{
    my $c = shift;
    my $conf = shift;
    my ($remport,$iaddr);
    
    if($#WAITING >= 0)
    {
	syswrite($WAITING[0]->{'fh'}, "CPU $c->{'host'}:$c->{'port'}\n", length("CPU $c->{'host'}:$c->{'port'}\n"))|| die "Could not realloc";
	$c->{'clientaddr'} = $WAITING[0]->{'host'};
	$c->{'clientport'} = $WAITING[0]->{'port'};
	$WAITING[0]->{'cpucount'}++;
	shift(@WAITING);
    }
    else
    {
	foreach my $ref (@CLIENTREFS)
	{
	    if($ref->{'cpuswanted'} > $ref->{'cpucount'})
	    {
		syswrite($ref->{'fh'}, "CPU $c->{'host'}:$c->{'port'}\n", length("CPU $c->{'host'}:$c->{'port'}\n"))|| die "Realloc 2";
		$ref->{'cpucount'}++;
		$c->{'clientaddr'} = $ref->{'host'};
		$c->{'clientport'} = $ref->{'port'};
		last;
	    }
	}
    }
}

sub handle_client
{
    my $ref = shift;
    my $conf = shift;
    my (@commands, $buf);

    my $ret = sysread($ref->{'fh'}, $buf, 8192);
    if($ret > 0)
    {
	@commands = split(/\n/, $buf);
    }
    else
    {
	$commands[0] = "quit";
    }
    foreach my $command (@commands)
    {
	chomp($command);
	$command =~ s/\r$//;
	if($command =~ /^addcpu/i) # cpucommands with host:port argument
	{
	    my @parts = split(/ /, $command);
	    my @subparts = split(/:/, $parts[1]);
	    my $newcpu = {};
	    $newcpu->{'host'} = $subparts[0];
	    $newcpu->{'port'} = $subparts[1];
	    push(@{$conf->{'cpus'}}, $newcpu); # und jetzt gucken ob wir clients haben und die CPU dahinverteilen
	    send_status_msgs("CPU $newcpu->{'host'}|$newcpu->{'port'}|idle\n");
	    realloc($newcpu, $conf);
	}
	elsif($command =~ /^delcpu/i)
	{
	    my $onecpu;
	    my @parts = split(/ /, $command);
	    my @hostport = split(/:/, $parts[1]);
	    foreach my $cpu (@{$conf->{'cpus'}})
	    {
		if(($cpu->{'host'} eq $hostport[0]) && ($cpu->{'port'} eq $hostport[1]))
		{
		    $cpu->{'deleteme'} = 1;
		    $onecpu = $cpu;
		    last;
		}
	    }
	    if(!$onecpu->{'busy'})
	    {
		send_status_msgs("DELCPU $onecpu->{'host'}|$onecpu->{'port'}\n");
		@{$conf->{'cpus'}} = grep((!defined($_->{'deleteme'}) || ($_->{'busy'})), @{$conf->{'cpus'}});
	    }
	    else
	    {
		foreach my $r (@CLIENTREFS)
		{
		    if(($onecpu->{'clientaddr'} eq $r->{'host'}) && ($onecpu->{'clientport'} == $r->{'port'}))
		    {
			syswrite($r->{'fh'}, "DELCPU $onecpu->{'host'}|$onecpu->{'port'}\n", length("DELCPU $onecpu->{'host'}|$onecpu->{'port'}\n"))|| die "Could not deletecpu $onecpu->{'host'}:$onecpu->{'port'} to $r->{'host'}:$r->{'port'}";
			last;
		    }
		}
	    }
	}
	elsif($command =~ /^getstatus/i) # no arg
	{
	    foreach my $bc (@{$conf->{'cpus'}})
	    {
		if($bc->{'busy'} == 1)
		{
		    syswrite($ref->{'fh'}, "CPU $bc->{'host'}:$bc->{'port'}\@$bc->{'clientaddr'}:$bc->{'clientport'}|$bc->{'cd'}|$bc->{'artist'}|$bc->{'song'}\n",
			     length("CPU $bc->{'host'}|$bc->{'port'}|$bc->{'clientaddr'}:$bc->{'clientport'}|$bc->{'cd'}|$bc->{'artist'}|$bc->{'song'}\n")) || die "Could not send status";
		}
		else
		{
		    if(defined($bc->{'clientaddr'}))
		    {
			syswrite($ref->{'fh'}, "CPU $bc->{'host'}:$bc->{'port'}\@$bc->{'clientaddr'}:$bc->{'clientport'}|idle\n",
				 length("CPU $bc->{'host'}|$bc->{'port'}|$bc->{'clientaddr'}:$bc->{'clientport'}|idle\n"))|| die "Could not send status II";
		    }
		    else
		    {
			syswrite($ref->{'fh'}, "CPU $bc->{'host'}|$bc->{'port'}|idle\n", length("CPU $bc->{'host'}|$bc->{'port'}|idle\n"))|| die "Could not send status 3";
		    }
		}
	    }
	}
	elsif($command =~ /^getcpu/i) # arguments number of tracks
	{
	    my @cpus = grep((!($_->{'busy'}) && !($_->{'deleteme'})), @{$conf->{'cpus'}});
	    my @parts = split(/ /, $command);
	    $ref->{'cpuswanted'} = $parts[1];
	    if($#cpus < 0) # auf die Wartebank schieben
	    {
		syswrite($ref->{'fh'}, "WAIT\n", 5)|| die "Could not send wait";
		push(@WAITING, $ref);
	    }
	    else
	    {
		my $count = 1;
		foreach my $c (@cpus)
		{
		    last if $count > $parts[1];
		    $c->{'clientaddr'} = $ref->{'host'};
		    $c->{'clientport'} = $ref->{'port'};
		    $c->{'busy'} = 1;
		    $ref->{'cpucount'}++;
		    syswrite($ref->{'fh'}, "CPU $c->{'host'}:$c->{'port'}\n", length("CPU $c->{'host'}:$c->{'port'}\n"))||die "Could not send cpu";
		    send_status_msgs("CPU $c->{'host'}:$c->{'port'}\@$c->{'clientaddr'}:$c->{'clientport'}|idle\n");
		    $count++;
		}
	    }
	}
	elsif($command =~ /^releasecpu/i) #argument host:port
	{
	    my ($remport, $iaddr, $cpu);
	    my @parts = split(/ /, $command);
	    my ($host, $port) = split(/:/, $parts[1]);
	    foreach my $c (@{$conf->{'cpus'}})
	    {
		if(($c->{'clientaddr'} eq $ref->{'host'}) && ($c->{'clientport'} == $ref->{'port'}) && ($c->{'host'} eq $host) && ($c->{'port'} == $port))
		{
		    my $msg;
		    delete($c->{'clientaddr'});
		    delete($c->{'clientport'});
		    delete($c->{'busy'});
		    $ref->{'cpucount'}--;
		    $ref->{'cpuswanted'} = $ref->{'cpucount'};
		    if(defined($c->{'deleteme'})) # loeschen, sonst reallocen, falls wir noch einen haben
		    {
			@{$conf->{'cpus'}} = grep($_ != $c, @{$conf->{'cpus'}});
			$msg = "DELCPU $c->{'host'}|$c->{'port'}\n";
		    }
		    else
		    {
			realloc($c,$conf);
			$msg = "CPU $c->{'host'}|$c->{'port'}|idle\n";
		    }
		    send_status_msgs($msg);
		    last;
		}
	    }
	}
	elsif($command =~ /^statusupdate/i) #argument HOST:PORT|CDTITLE|ARTIST|SONGTITLE
	{
	    my ($remport, $iaddr, $cpu);
	    $command=~/^statusupdate (.*)$/;
	    my @parts = split(/ /, $command);
	    my @subparts = split(/\|/, $1);
	    my ($host, $port) = split(/:/, $subparts[0]);
	    my @onecpu = grep((($_->{'clientaddr'} eq $ref->{'host'}) && ($_->{'clientport'} == $ref->{'port'}) 
			       && ($_->{'host'} eq $host) && ($_->{'port'} == $port)), @{$conf->{'cpus'}});
	    my $oc = $onecpu[0];
	    $oc->{'cd'} = $subparts[1];
	    $oc->{'artist'} = $subparts[2];
	    $oc->{'song'} = $subparts[3];
	    send_status_msgs("CPU $oc->{'host'}:$oc->{'port'}\@$oc->{'clientaddr'}:$oc->{'clientport'}|$oc->{'cd'}|$oc->{'artist'}|$oc->{'song'}|$oc->{'bytesfinished'}|$oc->{'size'}|$oc->{'rate'}\n");
	}
	elsif($command =~ /^sendstatusupdates/i) # no arguments just a statusviewerclient
	{
	    push(@STATUSRECEIVERS, $ref->{'fh'});
	}
	elsif($command =~ /^perfupdate/)
	{
	    $command =~ s/^perfupdate (.*)/$1/;
	    my($cpu, $bytes, $size, $rate) = split(/\|/, $command);
	    my($host, $port) = split(/:/, $cpu);
	    my @onecpu = grep((($_->{'clientaddr'} eq $ref->{'host'}) && ($_->{'clientport'} == $ref->{'port'}) 
			       && ($_->{'host'} eq $host) && ($_->{'port'} == $port)), @{$conf->{'cpus'}});
	    my $oc = $onecpu[0];
	    $oc->{'bytesfinished'} = $bytes;
	    $oc->{'size'} = $size if $size ne "";
	    $oc->{'rate'} = $rate;
	    send_status_msgs("CPU $oc->{'host'}:$oc->{'port'}\@$oc->{'clientaddr'}:$oc->{'clientport'}|$oc->{'cd'}|$oc->{'artist'}|$oc->{'song'}|$oc->{'bytesfinished'}|$oc->{'size'}|$oc->{'rate'}\n");
	}
	elsif(($command =~ /^quit/i) || ($command eq ""))
	{
	    my @cpus = grep(($_->{'clientaddr'} eq $ref->{'host'}) && ($_->{'clientport'} == $ref->{'port'}), @{$conf->{'cpus'}});
	    if(defined($ref->{'cpuswanted'}) && ($ref->{'cpuswanted'} > $ref->{'cpucount'}))
	    {
		$ref->{'cpuswanted'} = $ref->{'cpucount'};
	    }
	    foreach my $c (@cpus)
	    {
		# busy auf null setzen, reallocen statusupdaten
		my $msg;
		delete($c->{'busy'});
		delete($c->{'clientaddr'});
		delete($c->{'clientport'});
		delete($c->{'bytesfinished'});
		delete($c->{'size'});
		delete($c->{'rate'});
		if(defined($c->{'deleteme'}))
		{
		    @{$conf->{'cpus'}} = grep($_ != $c, @{$conf->{'cpus'}});
		    $msg = "DELCPU $c->{'host'}|$c->{'port'}\n";
		}
		else
		{
		    realloc($c);
		    $msg = "CPU $c->{'host'}|$c->{'port'}|idle\n";
		}
		send_status_msgs($msg);
	    }
	    vec($readfds, fileno($ref->{'fh'}), 1) = 0;
	    close($ref->{'fh'});
	    @STATUSRECEIVERS = grep($_ != $ref->{'fh'}, @STATUSRECEIVERS);
	    @CLIENTREFS = grep ($_ != $ref, @CLIENTREFS);
	}
	else
	{
	    syswrite($ref->{'fh'}, "ERROR Unknown command\n", length("ERROR Unknown command\n"))|| die "Could not send errmsg";
	    return(-1);
	}
    }
}

getopts("c:");
$opt_c = "config" if $opt_c eq "";

$|=1;
$conf = read_config($opt_c);
if($conf->{'udspath'})
{
    my $udsfh = FileHandle->new();
    socket($udsfh, PF_UNIX, SOCK_STREAM, 0);
    bind($udsfh, sockaddr_un($conf->{'udspath'}));
    listen($udsfh, SOMAXCONN);
    push(@LISTENFDS, $udsfh);
}
if($conf->{'port'})
{
#    my $inetfh = FileHandle->new();
    my $proto = getprotobyname("tcp");
    socket(SOCK, PF_INET, SOCK_STREAM, $proto) || die "Coudn't create socket $!";
    $inetfh = \*SOCK;
    setsockopt($inetfh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "Coudlnt setsockopt $!";
    bind($inetfh, sockaddr_in($conf->{'port'}, INADDR_ANY))|| die "Couldn't bind $!";
    listen($inetfh, SOMAXCONN);
    push(@LISTENFDS, $inetfh);
}
$readfds="";
foreach my $fh (@LISTENFDS)
{
    vec($readfds, fileno($fh), 1)=1;
}

while(1)
{
    $nfound = select($r=$readfds, undef, undef, undef);
    last if $nfound == 0;
    while($nfound > 0)
    {
	foreach my $fh (@LISTENFDS)
	{
	    if(vec($r, fileno($fh), 1) == 1)
	    {
		$nfound--;
		my $newfh = FileHandle->new();
		accept($newfh, $fh);
		vec($readfds, fileno($newfh), 1)=1;
		my $newref = {};
		$newref->{'fh'} = $newfh;
		my ($port, $remia) = unpack_sockaddr_in(getpeername($newfh));
		$newref->{'port'} = $port;
		$newref->{'host'} = inet_ntoa($remia);
		push(@CLIENTREFS, $newref);
	    }
	    last if $nfound == 0;
	}
	foreach my $ref (@CLIENTREFS)
	{
	    if(vec($r, fileno($ref->{'fh'}), 1) == 1)
	    {
		$nfound--;
		handle_client($ref, $conf);
	    }
	    last if($nfound == 0);
	}
    }
}
