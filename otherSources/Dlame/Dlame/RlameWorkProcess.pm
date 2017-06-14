package RlameWorkProcess;

use RipNLame;
use File::Copy;
use MP3::Info;

sub new
{
    my $class = shift;

    my $self = {};

    $self->{'inputfh'} = shift;
    $self->{'songinfo'} = shift;
    $self->{'filetitle'} = shift;
    $self->{'host'} = shift;
    $self->{'port'} = shift;
    $self->{'destdir'} = shift;
    $self->{'index'} = shift;
    $self->{'statusfh'} = shift;
    $self->{'cpusock'} = shift;
    $self->{'time'} = time();
    bless($self, $class);
}

sub do_work
{
    my $self = shift;

    my $pid;
    if(($pid = fork()) > 0)
    {
	$self->{'pid'} = $pid;
    }
    else
    {
	$SIG{'CHLD'} = 'IGNORE';
	$SIG{'CLD'} = 'IGNORE';
	# Kindteil
	my $filetitle = create_filetitle($self->{'songinfo'}->{'lied'});
	my $index = $self->{'index'};
	$index = "0".$index if ($self->{'index'} < 10) && ($self->{'index'} !~ /^0/);

	open(OUTPUT, ">output$$.mp3");
	my $ret = do_remote_work($self->{'host'}, $self->{'port'}, $self->{'inputfh'}, \*OUTPUT, $self->{'statusfh'}, $self->{'cpusock'});
	print "Ret in RWP war $ret\n";
	if($ret == 1)
	{
	    close(OUTPUT);
	    close($self->{'inputfh'});
	    copy("output$$.mp3", "$self->{'destdir'}/Interpreten/$self->{'songinfo'}->{'artist'}/$filetitle");
	    set_mp3tag("$self->{'destdir'}/Interpreten/$self->{'songinfo'}->{'artist'}/$filetitle", $self->{'songinfo'}->{'lied'}, 
		       $self->{'songinfo'}->{'artist'}, $self->{'songinfo'}->{'title'}, "", "", $self->{'songinfo'}->{'cat'}, $self->{'index'});
	    setup_link($self->{'songinfo'}, $filetitle, $index, $self->{'destdir'});
	    unlink("output$$.mp3");
	    exit(0);
	}
	else
	{
	    exit(-1);
	}
    }
}

1;
