# $Id: RipNLame.pm,v 1.5 2000/08/28 18:27:51 elwood Exp $

package RipNLame;

use CDDB_get;
use MP3::Info;
use File::Copy;
use Socket;
require Exporter;

@ISA = qw( Exporter );
@EXPORT = qw(get_infos_from_files info_to_file file_to_info get_infos do_work do_remote_work setup_dirs create_filetitle setup_link);

sub get_infos_from_files
{
    my $dirname = shift;

    my $infos = [];
    opendir(DIR, $dirname);
    while(my $d=readdir(DIR))
    {
	next if($d eq ".") || ($d eq "..");
	push(@$infos, file_to_info("$dirname/$d"));
    }
    if($#$infos < 0)
    {
	return(undef);
    }
    else
    {
	return($infos);
    }
}

sub info_to_file
{
    my $filename = shift;
    my $cddbinfo = shift;

    open(FILE, ">$filename");
    print FILE "artist: $cddbinfo->{'artist'}\n";
    print FILE "title: $cddbinfo->{'title'}\n";
    print FILE "category: $cddbinfo->{'cat'}\n";
    print FILE "cddbid: $cddbinfo->{'id'}\n";
    print FILE "trackno: $cddbinfo->{'tno'}\n";
    print FILE "dev: $cddbinfo->{'dev'}\n";
    my $n=1;
    foreach my $i ( @{$cddbinfo->{'track'}} ) {
	print FILE "track $n: $i\n";
	$n++;
    }
    close(FILE);
}

sub file_to_info
{
    my $filename = shift;
    my $info = {};

    open(DISKID, $filename) || die "$filename not found";

    foreach my $key ((qw(artist title cat cddbid tno dev)))
    {
	my $line = <DISKID>;
	chomp($line);
	my @tmp=split(/:/,$line);
	$tmp[1] =~ s/^\s?//g; # Strip Leading whitespace
	$info->{$key} = $tmp[1];
    }
    $info->{'track'} = [];
    for(my $i=1; $i<=$info->{'tno'}; $i++)
    {
	$line = <DISKID>;
	chomp($line);
	@tmp=split(/:/,$line);
	$tmp[1] =~ s/^\s?//g; # Strip Leading whitespace
	push(@{$info->{'track'}}, $tmp[1]);
    }
    close(DISKID);
    return($info);
}

sub get_infos
{
    my $config = shift;
    my $devices = shift;
    my $datadir = shift;

    my $infos = [];
    
    foreach my $dev (@$devices)
    {
	$config->{'CD_DEVICE'} = $dev;
	my %cd = get_cddb($config);
	$cd{'dev'} = $dev;
	push(@$infos, \%cd);
	print "Got $cd{'title'}\n" if $main::debug;
	info_to_file("$datadir/$cd{'id'}", \%cd);
    }
    return($infos);
}

sub setup_dirs
{
    my $i = shift;
    my $destdir = shift;

    mkdir("$destdir/Interpreten/$i->{'artist'}", 0775) if ! -d "$destdir/Interpreten/$i->{'artist'}";
    mkdir("$destdir/Interpreten/$i->{'artist'}/Alben", 0775) if ! -d "$destdir/Interpreten/$i->{'artist'}/Alben";
    mkdir("$destdir/Interpreten/$i->{'artist'}/Alben/$i->{'title'}", 0775) if ! -d "$destdir/Interpreten/$i->{'artist'}/Alben/$i->{'title'}";
}

sub create_filetitle
{
    my $filetitle = shift;
    $filetitle =~ s/\s+/_/g;
    $filetitle .= ".mp3";
    $filetitle =~ s/\//-/g;
    return($filetitle);
}

sub setup_link
{
    my $i = shift;
    my $filetitle = shift;
    my $index = shift;
    my $destdir = shift;

    my $dir = `pwd`;
    chomp($dir);
    setup_dirs($i, $destdir);
    $index = "0".$index if ($index < 10) && ($index !~ /^0/);
    chdir("$destdir/Interpreten/$i->{'artist'}/Alben/$i->{'title'}") || die "Could not chdir to $destdir/Interpreten/$i->{'artist'}/Alben/$i->{'title'} reason $!";
    my $indextitle = $index."_$filetitle";
    symlink("../../$filetitle", $indextitle) unless -l $indextitle;
    chdir($dir);
}

sub do_work
{
    my $infos = shift;
    my $destdir = shift;
    my $remotehost = shift;
    my $remoteport = shift;

    foreach my $i (@$infos)
    {
	setup_dirs($i, $destdir);
	print "Working on $i->{'title'} from $i->{'artist'}\n";
	for(my $j=1; $j <= $i->{'tno'}; $j++)
	{
	    print "Track $j ".$i->{'track'}->[$j - 1]."\n";
	    my $index = $j;
	    $index = "0".$j if $j < 10;
	    my $filetitle = create_filetitle($i->{'track'}->[$j - 1]);
	    if(! -f "$destdir/Interpreten/$i->{'artist'}/$filetitle")
	    {
		if(!$remotehost)
		{
		    system("cdparanoia -q -d $i->{'dev'} -B $j -|lame -v -S --nohist - output.mp3 2>1 > /dev/null");
		}
		else
		{
		    open(PIPE, "cdparanoia -d $i->{'dev'} -B $j -|"); # da muss -q wieder rein
		    open(RAW, ">output.mp3");
		    do_remote_work($remotehost, $remoteport, \*PIPE, \*RAW) || system("cdparanoia -q -d $i->{'dev'} -B $j -|lame -v -S --nohist - output.mp3");
		    close(PIPE);
		    close(RAW);
		}
		copy("output.mp3", "$destdir/Interpreten/$i->{'artist'}/$filetitle");
		set_mp3tag("$destdir/Interpreten/$i->{'artist'}/$filetitle", $i->{'track'}->[$j - 1], $i->{'artist'}, $i->{'title'}, "", "", $i->{'cat'}, $j);
	    }
	    setup_link($i, $filetitle, $index, $destdir);
	}
    }
}

sub do_remote_work
{
    my $remotehost = shift;
    my $remoteport = shift;
    my $rawdatafh  = shift;
    my $mp3datafh  = shift;
    my $statusfh   = shift; # optional
    my $cpusock    = shift; # optional

    my($rin,$sin,$win,$r,$w,$done,$total_sent,$mbyte, $now, $oldsent);

    $mbyte = 0;

    socket(SOCK, PF_INET, SOCK_STREAM, 6)|| return(undef);
    $sin = sockaddr_in($remoteport, inet_aton($remotehost));
    connect(SOCK, $sin) || return(undef);
#fcntl(SOCK, F_SETFL, O_NONBLOCK);
    $rin=$win=$r=$w='';
    vec($rin, fileno(SOCK), 1) = 1;
    vec($win, fileno(SOCK), 1) = 1;

    $now = time();
    while(!$done)
    {
	my $nfound = select($r=$rin, $w=$win, undef, undef);
	if($nfound > 0)
	{
	    if(vec($w, fileno(SOCK), 1) == 1)
	    {
		my ($buf, $bytes_send,$writes);
		my $bytes_read = sysread($rawdatafh, $buf, 1448) if $bytes_send == 0;
		if($bytes_read == 0) # eof
		{
		    vec($win, fileno(SOCK), 1) = 0;
		    shutdown(SOCK, 1);
		}
		$writes++;
		$bytes_send += syswrite(SOCK, $buf, $bytes_read);
		die if $bytes_send < $bytes_read;
		$total_sent+=$bytes_send;
		if(($statusfh) && ($total_sent > $mbyte))
		{
		    my $newtime = time();
		    if(($newtime - $now) > 0)
		    {
			$rate = ($total_sent - $oldsent)/($newtime - $now);
			$oldsent = $total_sent;
			syswrite($cpusock, "perfupdate $remotehost:$remoteport|$total_sent||$rate\n", length("perfupdate $remotehost:$remoteport|$total_sent||$rate\n")) if $cpusock;
		    }
		    $now = $newtime;
		    syswrite($statusfh, "$total_sent\n", length("$total_sent\n"));
		    $mbyte += 1024**2;
		}
		$bytes_send = 0 if $bytes_send == $bytes_read;
#	    $done = 1 if(($bytes_read == 0) && ($bytes_send == 0));
	    }
	    if(vec($r, fileno(SOCK), 1) == 1)
	    {
		my $line;
		$reads++;
		my $bytes = sysread(SOCK, $line, 15000);
		$total_read+=$bytes;
		$total_written+= syswrite($mp3datafh, $line, $bytes);
		$done=1 if $bytes == 0;
	    }
	}
    }
    if(($statusfh))
    {
	syswrite($statusfh, "$total_sent\n", length("$total_sent\n"));
	syswrite($cpusock, "perfupdate $remotehost:$remoteport|$total_sent||$rate\n", length("perfupdate $remotehost:$remoteport|$total_sent||$rate\n")) if $cpusock;
	close($statusfh);
    }
    return(1);
}
1;
