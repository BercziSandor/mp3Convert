use Getopt::Std;

getopts("s:d:");

opendir(DEST, $opt_d);
$max = 0;
while($entry = readdir(DEST))
{
    next if $entry !~ /^\d+/;
    my @parts = split(/_/, $entry);
    $max = $parts[0] if($parts[0] > $max);
}
closedir(DEST);
opendir(SOURCE, $opt_s);
$j=1;
while($entry = readdir(SOURCE))
{
    next if $entry !~ /^\d+/;
    my @parts = split(/_/, $entry);
    shift(@parts);
    my $destname = $opt_d."/".($max+$j)."_".join("_",@parts);
    rename("$opt_s/$entry", $destname);
    $j++;
}

