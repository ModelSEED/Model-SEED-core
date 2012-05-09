package ModelSEED::App::mseed::Command::error;
use base 'App::Cmd::Command';
use ModelSEED::Configuration;
use File::stat;
use Time::localtime;
sub abstract { return "Print information from the error log"; }
sub usage_desc { return <<END;
ms error [options] [n]
Print the most recent message from the error log.
If [n] is supplied, print the n'th most recent message.

END
}
sub opt_spec {
    return (
        ["list|l",    "list all recent errors"],
        ["verbose|v", "verbose list output"],
    );
}


sub execute {
    my ($self, $opts, $args) = @_;
    my $n = 0;
    if(@$args) {
        $n = $args->[0];
    }
    my $Config = ModelSEED::Configuration->new();
    my $dir = $Config->config->{error_dir};
    my ($sortedFiles, $filesModTime) = $self->_getOrderedFileList($dir);
    if($opts->{list} && $opts->{verbose}) {
        foreach my $file (@$sortedFiles) {
            $self->_printFileErrors($file, $filesModTime->{$file});
        }
    } elsif($opts->{list}) {
        foreach my $file (@$sortedFiles) {
            print $file."\t".ctime($filesModTime->{$file})."\n";;
        }
    } else {
        my $file = $sortedFiles->[$n];
        return unless $file;
        $self->_printFileErrors($file, $filesModTime->{$file});
        return;
    }
}

sub _getOrderedFileList {
    my ($self, $dir) = @_;
    my @files;
    { 
        opendir my $dh, $dir or die "Couldn't open dir $dir"; 
        @files = map { "$dir/$_" } grep { !/^\.\.?$/ } readdir $dh;
        close($dh);
    }
    my $filesModTime = {};
    foreach my $file (@files) {
        open(my $fh, "<", $file) or die "Couldn't open $file";
        $filesModTime->{$file} = stat($fh)->mtime;
        close($fh);
    }
    my @sortedFiles = sort {
        $filesModTime->{$b} <=> $filesModTime->{$a}
    } @files;
    return (\@sortedFiles, $filesModTime);
}

sub _printFileErrors {
    my ($self, $file, $modTime) = @_;
    print "Reading errors from $file at ".ctime($modTime).": \n";
    open(my $fh, "<", $file) or die "Could not open file $file";
    while(<$fh>) {
        print $_;
    }
    close($fh);
}

1;
