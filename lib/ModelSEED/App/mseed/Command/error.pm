package ModelSEED::App::mseed::Command::error;
use base 'App::Cmd::Command';
use ModelSEED::Configuration;
use File::stat;
use Time::localtime;
sub abstract { return "Print information from the error log"; }
sub usage_desc { return <<END;
ms error [n]
Print the most recent message from the error log.
If [n] is supplied, print the n'th most recent message.

END
}
sub execute {
    my ($self, $opts, $args) = @_;
    my $n = 0;
    if(@$args) {
        $n = $args->[0];
    }
    my $Config = ModelSEED::Configuration->new();
    my $dir = $Config->config->{error_dir};
    my @files;
    { 
        opendir my $dh, $dir or die "Couldn't open dir $dir"; 
        @files = map { "$dir/$_" } grep { !/^\.\.?$/ } readdir $dh;
        close($dh);
    }
    my $filesModTime = {};
    foreach my $file (@files) {
        open(my $fh, "<", $file) or die "Couldn't open $file";
        $filesModTime->{$file} = ctime(stat($fh)->mtime);
        close($fh);
    }
    my @sortedFiles = sort {
        $filesModTime->{$a} <=> $filesModTime->{$b}
    } @files;
    my $file = $sortedFiles[$n];
    return unless $file;
    print "Reading errors from $file: \n";
    open(my $fh, "<", $file) or die "Could not open file $file";
    while(<$fh>) {
        print $_;
    }
    return;
}

1;
