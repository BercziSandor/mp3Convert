#!/bin/perl

use warnings;
use strict;

use Config::IniFiles;    # http://search.cpan.org/~shlomif/Config-IniFiles-2.94/lib/Config/IniFiles.pm
use Cwd 'abs_path';
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Find;
use File::Find::Wanted;
use File::Type;
use MP3::Info;
use POSIX qw( strftime );
use Term::ReadLine;      # http://search.cpan.org/~flora/Term-ReadLine-1.14/lib/Term/ReadLine.pm
use Time::HiRes qw( time );
use Term::Title 'set_titlebar';

use File::Path qw(make_path);
use Getopt::Long;

our $cfg;
our $data;

sub getTimeFromSeconds
{
    my ( $t ) = shift;

    # $t -= ( 60 * 60 );
    my $retval = strftime( "%H:%M:%S", gmtime( $t ) );
    $retval =~ s/^00://;    # Stripping empty hours
    return $retval;
} ### sub getTimeFromSeconds

sub ini
{
    print( "ini()\n" );
    {
        my $lines   = 17;
        my $columns = 100;
        print "\e[8;$lines;${columns}t";
    }

    # Load Configfile contents
    {
        $cfg = Config::IniFiles->new( -file => "mp3convert.cfg" );
        print " Loading mp3convert.cfg...\n";
        foreach my $aSec ( $cfg->Sections ) {

            # Copy content to $data
            foreach my $aPar ( $cfg->Parameters( $aSec ) ) {
                my $val = $cfg->val( $aSec, $aPar );
                $data->{$aSec}->{$aPar} = $val;
            }

            #Executables
            if ( $aSec eq 'Executables' ) {
                print "  Checking existence of all executables...\n";
                foreach my $aPar ( $cfg->Parameters( $aSec ) ) {
                    my $val = $cfg->val( $aSec, $aPar );
                    print "  $aPar: [$val] ";
                    die "[$val] - it does NOT exist, aborting.\n" if ( not -e $val );
                    print " OK\n";
                } ### foreach my $aPar ( $cfg->Parameters...)
                    #Profiles
            } elsif ( $aSec =~ m/^settings/i ) {
            } elsif ( $aSec =~ m/^(profile_.*)/i ) {
                my ( $profile ) = $1;
                printf "  %-60s [%s]\n", $cfg->val( $profile, 'description' ), $cfg->val( $profile, 'lameParameters' );
                $data->{profiles}->{$profile}->{desc} = $cfg->val( $profile, 'description' );
                $data->{profiles}->{$profile}->{lame} = $cfg->val( $profile, 'lameParameters' );
            } ### elsif ( $aSec =~ m/^(profile_.*)/i)
        } ### foreach my $aSec ( $cfg->Sections)

    }

    # loadCommandLineArguments
    {
        $data->{recursive} = 1;
        $data->{verbose}   = 0;
        print " Parsing command line arguments...\n";
        GetOptions(
            "inputDir=s"  => \$data->{input},        # string
            "outputDir=s" => \$data->{output},       # string
            "recursive!"  => \$data->{recursive},    # flag
            "verbose"     => \$data->{verbose},      # flag
            "force"       => \$data->{force}         # flag
        ) or die( "Error in command line arguments\n" );

        die "Please provide input dir.\n" unless defined $data->{input};
        die "Input does not exist, aborting.\n" unless ( -e $data->{input} );
        $data->{input}      = abs_path( $data->{input} );
        $data->{input_root} = $data->{input};
        print "  Input  root: $data->{input_root}\n";

        die "Please provide output dir.\n" unless defined $data->{output};
        $data->{output} = abs_path( $data->{output} );
        print "  Output root: $data->{output}\n";
    }

    die "executables/tag not defined in the config file, aborting."     if ( not defined $data->{executables}->{tag} );
    die "executables/lame not defined in the config file, aborting."    if ( not defined $data->{executables}->{lame} );
    die "executables/mp3Gain not defined in the config file, aborting." if ( not defined $data->{executables}->{mp3Gain} );

    print( "ini() returning\n" );

} ### sub ini

sub my_system
{
    my ( $cmd ) = shift;

    my $start  = time();
    my $retval = system( $cmd);
    my $end    = time();

    printf( "[%s]: ", $cmd ) if $data->{verbose};
    printf( "elapsed time: %5.2fs", ( $end - $start ) );
    if ( $retval != 0 ) {
        print "Command failed, error message: \n";
        `$cmd`;
        $retval = -1;
    } else {
        $retval = ( $end - $start );
    }
    return $retval;

} ### sub my_system

sub removeSpecChars
{
    my $str = shift;
    print( "removeSpecChars($str)=" );
    $str =~ s/í/i/g;
    $str =~ s/Í/I/g;
    $str =~ s/É/E/g;
    $str =~ s/é/e/g;
    $str =~ s/Á/A/g;
    $str =~ s/á/a/g;

    $str =~ s/Ö/O/g;
    $str =~ s/ö/o/g;
    $str =~ s/Ő/O/g;
    $str =~ s/ő/o/g;

    $str =~ s/Ú/U/g;
    $str =~ s/ú/u/g;

    $str =~ s/&/ and /g;

    $str =~ s/Ü/U/g;
    $str =~ s/ü/u/g;
    $str =~ s/Ű/U/g;
    $str =~ s/ű/u/g;

    print( "$str\n" );
    return $str;
} ### sub removeSpecChars

sub getGetWinPath
{
    my $f = shift;
    $f = `cygpath -w \"$f\"`;
    chomp $f;
    return $f;
} ### sub getGetWinPath

sub processFile
{
    my ( $inFile, $outFile, $profileName, $normalize ) = @_;

    my $durationIn;
    my $sizeIn;
    my $bitrateIn;

    our $durationOut;
    our $sizeOut;
    our $bitrateOut;

    `clear`;
    print "\n\n____________________________________\n\n";

    my $inShortName = $inFile;
    $inShortName =~ s/$data->{input_root}//;
    $inShortName =~ s/^\///;

    # print "Processing file [$inShortName] with profile '$profileName'\n";
    set_titlebar( "$inShortName" );
    print "processFile('$inFile', '$outFile', '$profileName')\n" if $data->{verbose};
    my $outShortName = $outFile;
    $outShortName =~ s/$data->{output}//;
    $outShortName =~ s/^\///;
    my $outFileOrig;
    my $cmd;
    my $retval;

    my $lameParams;
    $lameParams .= $cfg->val( 'settings', 'lameParameterDefaults' ) if $cfg->exists( 'settings', 'lameParameterDefaults' );
    $lameParams .= " " . $cfg->val( $profileName, 'lameParameters' ) if $cfg->exists( $profileName, 'lameParameters' );

    # Check
    if ( not -e $inFile ) {
        die "$inFile does not exist, aborting.\n";
    } else {
        print " CHECK: $inFile exist: OK\n" if $data->{verbose};
    }

    my $ft = File::Type->new()->checktype_filename( $inFile );
    if ( $ft ne 'audio/mp3' ) {
        print " This file seems not to be a valid mp3 file (but $ft), copy unchanged.\n";
        if ( not -e $outFile ) {
            make_path( dirname( $outFile ) ) if ( not -e dirname( $outFile ) );
            copy( $inFile, $outFile ) or die "copy [$inFile] [$outFile]: $!\n";
        }
        return 1;
    } ### if ( $ft ne 'audio/mp3')

    $durationIn = get_mp3info( $inFile )->{SECS};
    $sizeIn     = get_mp3info( $inFile )->{SIZE} or die "Error reading size of the input file: $!\n";
    $bitrateIn  = get_mp3info( $inFile )->{BITRATE};
    printf(
        " Info (input)\n  Size:     %.2f MB\n  Duration: %s s\n  Bitrate:  %s kbps\n\n",
        $sizeIn / ( 1024 * 1024 ),
        getTimeFromSeconds( $durationIn ), $bitrateIn
    );

    $outFileOrig = $outFile;
    if ( not -e "/tmp/mp3Convert" ) {
        mkdir( "/tmp/mp3Convert" ) or die "$!";
    }

    if ( -e $outFileOrig ) {
        my $durationOut = get_mp3info( $outFile )->{SECS} or die "Unable to read lenght of the output file: $!";
        my $reencode = 0;
        if ( $data->{settings}->{force} ) {
            print " [$outShortName] already exist, but force mode enabled: it will be deleted.\n";
            $reencode = 1;
        } elsif ( ( $durationIn - $durationOut ) > 1 ) {
            print "The lenght of the output differs, the previous output is faulty... ("
              . getTimeFromSeconds( $durationOut )
              . " instead of "
              . getTimeFromSeconds( $durationIn )
              . "), it will be deleted.\n";
            $reencode = 1;
        } ### elsif ( abs( $durationIn ...))

        if ( $reencode ) {
            unlink $outFile or die "Error deleting file: $!\n";
        } else {
            print " [$outShortName] already exist (same length ok), skipping.\n";
            return 0;
        }
    } else {
        print " CHECK: $outShortName does not exist: OK\n" if $data->{verbose};
    }

    `rm /tmp/mp3Convert/* 2>1 > /dev/null`;
    $outFile = "/tmp/mp3Convert/" . time . ".out.tmp";
    copy( $inFile, "$outFile.orig.tmp" ) or die "$inFile: $!\n";
    $inFile = "$outFile.orig.tmp";

    die "There is no profile '$profileName'" if not $cfg->SectionExists( $profileName );

    print " Normalization... ";
    {
        # TODO: cfg
        if ( $normalize ) {
            unlink "$outFile.gained.tmp" if -e "$outFile.gained.tmp";
            copy( $inFile, "$outFile.gained.tmp" ) or die "$inFile: $!\n";
            $cmd = $cfg->val( 'executables', 'mp3Gain' ) . " /q /c /p /s r /a \"" . getGetWinPath( "$outFile.gained.tmp" ) . "\" 2>1 > /dev/null";
            print "\n  $cmd\n" if $data->{verbose};
            $retval = my_system( $cmd );
            if ( $retval == -1 ) {
                die "$cmd failed: $!\n";
            } else {

                # printf (" ok (%4.0fx)\n", $duration / $retval);
                print " ok (" . int( $durationIn / $retval ) . "x)\n";
            }
            $inFile = "$outFile.gained.tmp";
        } else {
            print " skipped\n";
        }
    }

    print " Transcoding...   ";
    {
        # TODO: cfg
        my $lame = $cfg->val( 'executables', 'lame' );
        $cmd = "$lame $lameParams    \"$inFile\" \"$outFile\" 2>1 > /dev/null";
        $cmd = "$lame $lameParams -S \"" . getGetWinPath( $inFile ) . "\" \"" . getGetWinPath( $outFile ) . "\" 2>1 > /dev/null";
        $cmd = "$lame $lameParams \"" . getGetWinPath( $inFile ) . "\" \"" . getGetWinPath( $outFile ) . "\"";
        print "  $cmd\n" if $data->{verbose};

        # my_system("/usr/local/bin/lame -v -S --nohist - /var/tmp/output.mp3 2>1 > /dev/null");
        $retval = my_system( $cmd );
        if ( $retval == -1 ) {
            `$cmd`;
            die "$cmd failed: $!\n";
        } else {
            print " ok (" . int( $durationIn / $retval ) . "x)\n";
        }

        $durationOut = get_mp3info( $outFile )->{SECS} or die "Error reading length of the output file: $!\n";
        $sizeOut     = get_mp3info( $outFile )->{SIZE} or die "Error reading size of the output file: $!\n";
        $bitrateOut  = get_mp3info( $outFile )->{BITRATE};
        my $undo = 0;
        if ( ( $sizeOut > $sizeIn * 0.8 ) and ( $sizeOut < $sizeIn ) ) {
            print "The size changed minimal -> compression undone";
            $undo = 1;
        } elsif ( $sizeOut > $sizeIn ) {
            print "The output is bigger than the input!!!! - compression undone.\n";
            $undo = 1;
        }
        if ( $undo ) {
            unlink $outFile;
            copy( $inFile, $outFile ) or die "copy [$inFile] [$outFile]: $!\n";
            $durationOut = get_mp3info( $outFile )->{SECS} or die "Error reading length of the output file: $!\n";
            $sizeOut     = get_mp3info( $outFile )->{SIZE} or die "Error reading size of the output file: $!\n";
            $bitrateOut  = get_mp3info( $outFile )->{BITRATE};
        } ### if ( $undo )
    }

    print " Tag copy...      ";
    {
        my $tag = $cfg->val( 'executables', 'tag' );
        $cmd =
            "$tag --fromfile \""
          . getGetWinPath( $inFile )
          . "\" --hideinfo --hidetags --hidenames --zeropad --commafix --spacefix \""
          . getGetWinPath( $outFile )
          . "\" 2>1 > /dev/null";
        print "  $cmd\n" if $data->{verbose};
        $retval = my_system( $cmd );
        if ( $retval == -1 ) {
            `$cmd`;
            die "$cmd failed: $!\n";
        } else {
            print " ok \n";
        }
    }

    {
        my $outDir = dirname( $outFileOrig ) or die "zaza! $!\n";
        if ( not -e $outDir ) {
            make_path( $outDir ) or die "Error creating directory $outDir: $!\n";
        } else {
            print " CHECK: [$outDir] exists: OK\n" if $data->{verbose};
        }
        rename( $outFile, $outFileOrig ) or die "$!";
    }

    # INFO (out)
    #
    # sub info_out
    {

        warn "Warning: The lenght of the output differs.... ($durationIn -> $durationOut)\n" if ( ( $durationIn - $durationOut ) > 1 );

        printf(
            " Info (output)\n  Size:     %.2f MB: %.2f%%\n  Duration: %s  OK\n  Bitrate:  %s kbps: %.2f%%\n\n",
            $sizeOut / ( 1024 * 1024 ),
            ( 0.0 + ( 100 * $sizeOut / $sizeIn ) ),
            getTimeFromSeconds( $durationOut ),
            $bitrateOut,
            ( 0.0 + ( 100 * $bitrateOut / $bitrateIn ) ),

        );
    }

    # printf( "Output size:    %.2fMB: %.2f%%\n", $sizeOut / ( 1024 * 1024 ), ( 0.0 + ( 100 * $sizeOut / $sizeIn ) ) );
    # printf( "Output bitrate: %s kbps\n", $bitrateOut );
    unlink "$outFile.gained" if -e "$outFile.gained";
    return 0;

} ### sub processFile

sub getFilesFromDir
{
    my ( $rootDir ) = shift;
    print( "getFilesFromDir($rootDir)..." );

    # my @files = find_wanted( sub { -f && /.mp3$/i }, $rootDir );
    my @files = find_wanted( sub { -f }, $rootDir );
    print( " done\n" );
    return \@files;

} ### sub getFilesFromDir

sub demo()
{
    print "Demo mode\n";

    foreach my $file ( @{ getFilesFromDir( $data->{input} ) } ) {
        my $fileName = basename( $file );
        $fileName = removeSpecChars( $fileName ) if $data->{settings}->{removeAccentsFromFileNames};
        my $pathName = dirname( $file );
        $pathName =~ s/$data->{input_root}//;
        $pathName =~ s/^\///;
        foreach my $profile ( sort keys %{ $data->{profiles} } ) {
            my $outFile = "$data->{output}/${pathName}" . ( $pathName ? "/" : "" );
            $outFile = removeSpecChars( $outFile ) if $data->{settings}->{removeAccentsFromPathNames};
            $outFile = $outFile . "${fileName}";
            processFile( $file, $outFile, $profile, $data->{settings}->{regainFiles} );
        } ### foreach my $profile ( sort ...)
    } ### foreach my $file ( @{ getFilesFromDir...})

    # foreach my $profile ( sort keys %{ $data->{profiles} } ) {
    #     my $outFile = "./output/${profile}/a.mp3";
    #     unlink $outFile if ( -e $outFile );
    #     processFile( "$inRoot/a.mp3", $outFile, $profile, 1 );
    # }
    print "Demo returning.\n";
} ### sub demo

ini();

demo();
