use RipNLame;
use Getopt::Std;

getopts("f:d:");

$info = file_to_info($opt_f);
chdir("$opt_d/$info->{'artist'}/Alben");
mkdir($info->{'title'},0775) if ! -d $info->{'title'};
chdir($info->{'title'}) || die "Can't chdir";
for($i=0; $i < $info->{'tno'}; $i++)
{
    my $index = $i+1;
    $index = "0".$index if $index < 10;
    my $filetitle = create_filetitle($info->{'track'}->[$i]);
    symlink("../../$filetitle", $index."_$filetitle");
}
