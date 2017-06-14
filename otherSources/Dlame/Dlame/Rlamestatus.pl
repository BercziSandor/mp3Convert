#! /usr/local/bin/perl
use Curses;
use Socket;
use Getopt::Std;

sub parse_cpu_ref
{
    my $cpu = shift;
    my $index = shift;
    $cpu =~ s/CPU (.*)/$1/;
    local($hport,$album,$interpret,$song,$bytesfinished, $size, $rate) = split(/\|/, $cpu);
    my $cpuref = {};
    if($hport =~ /@/)
    {
	my @parts = split(/@/, $hport);
	($cpuref->{'host'}, $cpuref->{'port'}) = split(/:/, $parts[0]);
	($cpuref->{'clientaddr'}, $cpuref->{'clientport'}) = split(/:/, $parts[1]);
	foreach my $k ((qw(album interpret song bytesfinished size rate)))
	{
	    $cpuref->{$k} = $$k;
	}
    }
    else
    { # idle
	$cpuref->{'host'} = $hport;
	$cpuref->{'port'} = $album;
    }
    $cpuref->{'index'} = $index;
    return($cpuref);
}

sub display
{
    my $cpus = shift;
    my $index = shift;

    my $empty = " "x80;
    addstr($index * 2, 0, $empty);
    addstr($index * 2 + 1, 0, $empty);
    if($cpus->[$index]->{'clientaddr'})
    {
	my $percent;
	if($cpus->[$index]->{'size'} > 0)
	{
	    $percent = sprintf("%3.2f",$cpus->[$index]->{'bytesfinished'} / $cpus->[$index]->{'size'} * 100);
	}
	my $rate = sprintf("%8.2f", $cpus->[$index]->{'rate'});
	addstr($index * 2    , 0, "CPU $cpus->[$index]->{'host'}:$cpus->[$index]->{'port'} working for $cpus->[$index]->{'clientaddr'}:$cpus->[$index]->{'clientport'} $percent% $rate");
	addstr($index * 2 + 1, 0, "$cpus->[$index]->{'interpret'}\t$cpus->[$index]->{'album'}\t$cpus->[$index]->{'song'}");
    }
    else
    {
	addstr($index * 2, 0, "CPU $cpus->[$index]->{'host'}:$cpus->[$index]->{'port'} idle");
    }
    my $time = localtime(time());
#    addstr($#$cpus * 2 + 3, 0, "$index $time");
    addstr(20,0,"$index $time");
    refresh();
}

sub find_index
{
    my $cpus = shift;
    my $ref = shift;

    foreach my $cp (@$cpus)
    {
	if(($cp->{'host'} eq $ref->{'host'}) && ($cp->{'port'} eq $ref->{'port'}))
	{
	    foreach my $k ((qw(clientaddr clientport album interpret song bytesfinished size rate)))
	    {
		if(defined($ref->{$k}))
		{
		    $cp->{$k} = $ref->{$k};
		}
		else
		{
		    delete($cp->{$k});
		}
	    }
	    return $cp->{'index'};
	}
    }
    $ref->{'index'} = $#CPUS+1;
    push(@CPUS, $ref);
    return($#CPUS);
}

getopts("r:");
$|=1;
$opt_r = "127.0.0.1:8888" if($opt_r eq "");
($remotehost,$remoteport)= split(/:/, $opt_r);
socket(CPUSOCK, PF_INET, SOCK_STREAM, 6)|| die "Can't create socket";
my $sin = sockaddr_in($remoteport, inet_aton($remotehost));
connect(CPUSOCK, $sin) || die "Can't connect to CPU-Broker";
my $rin="";
vec($rin, fileno(CPUSOCK), 1)=1;
syswrite(CPUSOCK,"getstatus\n", 10);
sleep(2);
($nfound, $timeleft) = select($r=$rin, undef, undef, undef);
sysread(CPUSOCK, $buf, 8192);
@cpulines = split(/\n/, $buf);
$i=0;
initscr();
noecho();
clear();
foreach my $cpu (@cpulines)
{
    my $cpuref = parse_cpu_ref($cpu, $i);
    push(@CPUS, $cpuref);
    display(\@CPUS, $i);
    $i++;
}

syswrite(CPUSOCK,"sendstatusupdates\n",18);
while(!$done)
{
    ($nfound, $timeleft) = select($r=$rin, undef, undef, undef);
    my $ret=sysread(CPUSOCK, $buf, 8192);
    last if ($ret == 0);
    my @cpulines = split(/\n/, $buf);
    foreach my $cpu (@cpulines)
    {
	my $cpuref = parse_cpu_ref($cpu, $i++);

	if($cpu =~ /^CPU/)
	{
	    display(\@CPUS, find_index(\@CPUS, $cpuref));
	}
	elsif($cpu =~ /^DELCPU/)
	{
	    @CPUS = grep(($_->{'host'} ne $cpuref->{'host'}) && ($_->{'port'} != $cpuref->{'port'}), @CPUS);
	    clear();
	    for(my $i=0; $i <= $#CPUS; $i++)
	    {
		display(\@CPUS, $i);
	    }
	}
    }
}
endwin();
