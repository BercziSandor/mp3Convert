#! /usr/bin/perl
# $Id: ripper.pl,v 1.1 2000/08/13 17:19:12 elwood Exp $

use CDDB_get;
use Getopt::Std;

sub usage
{
    print "Usage: ripper.pl -d wavmasterdir -D datafiledir\n";
    exit(0);
}


%config;
$config{CDDB_HOST}="10.1.1.1";    # set cddb host
$config{CDDB_PORT}=888;                # set cddb port
$config{CD_DEVICE}="/dev/cdrom";       # set cd device

my %cd=get_cddb(\%config);

getopt("d:D:h");
$opt_d || usage();
$opt_D || usage();
$opt_h && usage();

unless(defined $cd{title}) {
  die "no cddb entry found";
}

chdir($opt_D) || die "Can't chdir to $opt_D reason $!";
open(FILE, ">$cd{'id'}") || die "Can't open Datafile";
print FILE "artist: $cd{'artist'}\n";
print FILE "title: $cd{'title'}\n";
print FILE "category: $cd{'cat'}\n";
print FILE "cddbid: $cd{'id'}\n";
print FILE "trackno: $cd{'tno'}\n";
print FILE "dev: /dev/cdrom\n";

my $n=1;
foreach my $i ( @{$cd{'track'}} ) {
  print FILE "track $n: $i\n";
  $n++;
}
close(FILE);
chdir($opt_d) || die ("Can't chdir to $opt_d reason $!");
mkdir($cd{'id'},0770) || die "Can't create die $cd{'dir'} reason $!";
chdir($cd{'id'}) || die "Can't chdir to $cd{'dir'} reason $!";
system('cdparanoia -B "1-"');
