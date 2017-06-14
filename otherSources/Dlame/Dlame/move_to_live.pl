use RipNLame;

my $info = file_to_info("/var/tmp/mp3/data/d00eff0e");
$path="/var/tmp/mp3/Interpreten";
my $i=1;
foreach $t (@{$info->{'track'}})
{
    my $filename=create_filetitle($t);
    my $index=$i;
    $index = "0$index" if $i < 10;
    $newfilename = $filename;
    $newfilename =~ s/\.mp3$//;
    $newfilename .="_(unplugged).mp3";
    rename("$path/$info->{'artist'}/$filename","$path/$info->{'artist'}/$newfilename");
    symlink("../../$newfilename","$path/$info->{'artist'}/Alben/$info->{'title'}/".$index."_$newfilename");
    $i++;
}
