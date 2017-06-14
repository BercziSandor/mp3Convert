use MP3::Info;
use Getopt::Std;

getopts("d:D:");
$zielalbum = $opt_D;
$zielalbum =~ s/^Alben\///;
opendir(DIR, $opt_d) || die "Could not open directory $opt_d\n";
while($entry = readdir(DIR))
{
    next if $entry !~ /\.mp3$/;
    my $info = get_mp3tag("$opt_d/$entry");
    my $filetitle = $info->{'TITLE'};
    if($zielalbum =~ /^$info->{'ALBUM'}/)
    {
	print "Entry: $entry Trackno: $info->{'TRACKNUM'}\n";
	$max = $info->{'TRACKNUM'} if($max < $info->{'TRACKNUM'});
    }
    else
    {
	my $wentry={};
	$wentry->{'info'} = $info;
	$wentry->{'filename'} = $entry;
	push(@WORK, $wentry);
    }
}
#@keys = sort {$a->{'info'}->{'TRACKNUM'} cmp $b->{'info'}->{'TRACKNUM'}} (@WORK);
chdir($opt_D);
foreach my $w (@WORK)
{
    print "$w->{'filename'} ".($w->{'info'}->{'TRACKNUM'}+$max)."\n";
    symlink("../../$w->{'filename'}", ($w->{'info'}->{'TRACKNUM'}+$max)."_$w->{'filename'}");
}
