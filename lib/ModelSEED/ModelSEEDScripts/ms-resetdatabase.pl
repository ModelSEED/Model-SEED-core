#!/usr/bin/perl -w
########################################################################
# This perl script configures a model seed installation
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 8/29/2011
########################################################################
use strict;
use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use Cwd qw(abs_path);
use File::Path;
use Data::Dumper;

my $directoryRoot = abs_path($0);
my $args = {};
my $result = GetOptions(
    "address|a=s@" => \$args->{"-address"},
);
if (!defined($args->{"-address"})) {
	$args->{"-address"} = "http://bioseed.mcs.anl.gov/~devoid/ModelDB-sqlite.tgz";
}
my ($fh, $filename) = File::Temp::tempfile("databasedownload.XXXX");
close($fh);
system("curl ".$args->{"-address"}." > ".$filename);
system("tar -xzf ".$filename." -C ".$directoryRoot."../data/");
system("sqlite3 ".$directoryRoot."../data/ModelDB/ModelDB.db < ".$directoryRoot."../data/ModelDB/ModelDB.sqlite");
unlink($directoryRoot."../data/ModelDB/ModelDB.sqlite");

__DATA__

=head1 NAME

ms-resetdatabase - resets the sql-lite database in the Model SEED

=head1 SYNOPSIS

ms-resetdatabase

Options:

    --address [-a]                     Address that the new database will be downloaded from.
    
=cut
