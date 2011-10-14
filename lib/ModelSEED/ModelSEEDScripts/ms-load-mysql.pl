#!/usr/bin/perl -w
########################################################################
# Generate mysql schema (and potentially load mysql from dumpfile)
# Author: Scott Devoid
# Date of script creation: 10/10/2011
########################################################################
use strict;
use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use File::Path;
use LWP::Simple;
use Archive::Tar;
use File::Temp;
use ModelSEED::FIGMODEL;
my ($empty, $file, $man, $help);
my $restult = GetOptions(
    "empty" => \$empty,
    "sql|file=s" => \$file,
    "man" => \$man,
    "help|?" => \$help,
) || pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
if($file && $empty) {
    pod2usage(2);
}
if($file) {
    # Initialize with file if provided
    die "Unable to find file $file" unless(-f $file);
    loadMySQL($file);
} elsif($empty) {
    # Initialize empty db if that's what we want
    initEmptyMySQL();
} else {
    # Otherwise download file and install
    my $url = "http://bioseed.mcs.anl.gov/~devoid/ModelDB-mysql.tgz";
    my $file = downloadMySQL($url);  
    warn $file;
    loadMySQL($file);
}

sub downloadMySQL {
    my ($url) = @_;
    my ($tmpFH, $tmpFile) = File::Temp::tempfile(); 
    close($tmpFH);
    my $rtv = LWP::Simple::getstore($url, $tmpFile);
    die("\nUnable to download file from $url\nStatus: HTML $rtv\n") unless($rtv == 200);
    my $tar = Archive::Tar->new();
    my $dir = File::Temp::tempdir();
    $tar->setcwd($dir);
    $tar->read($tmpFile);
    $tar->extract();
    $dir =~ s/\/$//;
    my $extractFile = "$dir/ModelDB/ModelDB.mysql";
    die "Could not find mysql file at: $extractFile"
        unless(-f $extractFile);
    return $extractFile;
}

sub loadMySQL {
    my ($file) = @_;
    my $config = getMySQLConfig();
    my $cmd = "mysql --database=ModelDB --host=".$config->{host}.
        " --port=".$config->{port}." --socket=".$config->{socket}.
        " --user=".$config->{user};
    $cmd .= " --password=".$config->{password} if(defined($config->{password}));
    system($cmd . " < $file");
}

sub getMySQLConfig {
    my $fm = ModelSEED::FIGMODEL->new();
    ## Attempt to get configuration for ModelDB
    my $config = { host => undef, user => undef,
                   password => "", socket => undef, port => 3306};
    my $dbConfig = $fm->_get_FIGMODELdatabase_config();
    foreach my $key (keys %$dbConfig) {
        next unless $key =~ /PPO_tbl_.*/;
        next unless(defined($dbConfig->{$key}->{name}));
        next unless($dbConfig->{$key}->{name}->[0] eq "ModelDB");
        foreach my $var (keys %$config) {
            $config->{$var} = $dbConfig->{$key}->{$var}->[0] ||
                $config->{$var};
        }
        last; 
    }
    return $config;
}
    
            
sub initEmptyMySQL {
    my $config = getMySQLConfig();  
    my $root = $ENV{MODEL_SEED_CORE};
    $root =~ s/\/$//;
    my $cmd = "perl $root/lib/PPO/ppo_generate.pl ".
        "-xml $root/lib/ModelSEED/ModelDB/ModelDB.xml ".
        "-backend MySQL " .
        "-host " . $config->{host} .
        " -database ModelDB " .
        " -user " . $config->{user} .
        " -port " . $config->{port} .
        " -socket " . $config->{socket};
    $cmd .= " -password ".$config->{password} if(defined($config->{password}));
    print $cmd;
    system($cmd);
}
__DATA__

=head1 NAME

ms-load-mysql - optionally download, install mysql data in configured database

=head1 SYNOPSIS

ms-config [args...]

If no arguments are provided, utility downloads MySQL dump from the
central database and uploads it into the configured MySQL database
(use ms-config to change configuration parameters).

Options:

    --help [-h]                     brief help message
    --man                           returns this documentation
    --empty                         initializes completely empty database
    --file                          MySQL dump file to load
    
=cut
