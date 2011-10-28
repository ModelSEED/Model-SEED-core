#!/usr/bin/env perl
use Getopt::Long;
use File::Basename;
use Pod::Usage;

my $basename = dirname($0);
my $localLib = undef;
my $help = undef;
GetOptions(
    "l|local-lib=s" => \$localLib,
    "L|local-lib-contained=s" => \$localLibC,
    "man|help|?" => \$help
) or pod2usage(2);
pod2usage(1) if $help;
my $module_list_file = shift @ARGV || "$basename/module-list";
my $perl = `which perl`;
my $cpanm = `which cpanm`;
if(!defined($cpanm)) {
    my $cpanm = getCpan();
}
chomp $cpanm;
open(my $fh, "<", $module_list_file) || die("Could not open file: $module_list_file, $@");
while(<$fh>) {
    my $mod = $_;
    chomp $mod;
    my $cmd = $cpanm;
    if($localLib) {
        $cmd .= " -l $localLib";
    }
    if($localLibC) {
        $cmd .= " -L $localLibC";
    }
    print "Building $mod\n";
    print "$cmd $mod\n";
    system($cmd." $mod");
    if( ($? >> 8) ne 0) {
        print "Build of $mod died\n";
        exit 1;
    }
}
close($fh); 

sub getCpan {
    my $url = "http://cpanmin.us";
    my $curl = `which curl`;
    my $wget = `which wget`;
    my ($fh, $filename) = File::Temp::tempfile();
    close($fh);
    if($curl ne "") {
        system("$curl -o $filename $url");
    } elsif($wget ne "") {
        system("$wget -O $filename $url");
    } else {
        warn "Please install curl on your system.";
    }
    return $filename; 
}

=head1 ms-build-modules

ms-build-modules - Build required Perl modules for ModelSEED distribution.

=head1 SYNOPSIS

ms-build-modules downloads and installs Perl modules that are needed
to run ModelSEED software. Without any arguments, it will install
all modules in the user's home directory under ~/perl5.

ms-build-modules [options] [module-list-file]

    Options:
        -help           This help message
        -l directory    Install modules to alternate Perl5 directory

    Arguments:
        module-list-file    A list of modules, one per line, that are required
 
=cut
    
