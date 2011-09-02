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
use Cwd qw(abs_path);
use File::Path qw(make_path);
use Data::Dumper;

my $args = {};
my $result = GetOptions(
    "p|installation_directory=s" => \$args->{"-p"},
    "d|data_directory=s" => \$args->{"-d"},
    "cplex|cplex_licence=s" => \$args->{"-cplex"},
    "os|operating_system=s" => \$args->{"-os"},
    "usr|username=s" => \$args->{"-usr"},
    "figconfig=s" => \$args->{"-figconfig"},
    "dbhost=s" => \$args->{"-dbhost"},
    "dbuser=s" => \$args->{"-dbusr"},
    "dbpwd=s" => \$args->{"-dbpwd"},
    "h|help" => \$args->{"help"},
    "man" => \$args->{"man"},
) || pod2usage(2);

pod2usage(1) if $args->{"help"};
pod2usage(-exitstatus => 0, -verbose => 2) if $args->{"man"};
pod2usage(1) unless(defined($args->{"-p"}) && defined($args->{"-d"}));

my $extension = ".sh";
if (defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
    $extension = ".bat";
}
# Setting paths to absolute, otherwise a path like ../../foo/bar would cause massive issues...
$args->{"-p"} = abs_path($args->{"-p"}).'/';
$args->{"-d"} = abs_path($args->{"-d"}).'/';
$args->{"-cplex"} = abs_path($args->{"-cplex"}) if(defined($args->{"-cplex"}));
$args->{"-figconfig"} = abs_path($args->{"-figconfig"}) if(defined($args->{"-figconfig"}));
$args->{"-dbhost"} = abs_path($args->{"-dbhost"}) if(defined($args->{"-dbhost"}) && -f$args->{"-dbhost"});

#Creating FIGMODELConfig.txt
{
    my $data = loadFile($args->{"-p"}."lib/ModelSEED/FIGMODELConfig.txt");
    for (my $i=0; $i < @{$data}; $i++) {
        my ($key, @values) = split(/\|/, $data->[$i]); 
        if ($key =~ m/database\sroot\sdirectory/) {
            $data->[$i] = "database root directory|".$args->{"-d"};
        } elsif ($key =~ m/software\sroot\sdirectory/) {
            $data->[$i] = "software root directory|".$args->{"-p"};
        }
    }
printFile($args->{"-p"}."config/FIGMODELConfig.txt",$data);
}
#Creating shell scripts
my ($modeldriver,$queuedriver);
$modeldriver = ["source ".$args->{"-p"}."bin/envConfig".$extension];
$queuedriver = ["source ".$args->{"-p"}."bin/envConfig".$extension];
if (defined($args->{"-cplex"})) {
    push(@{$queuedriver},"export ILOG_LICENSE_FILE=".$args->{"-cplex"});
    push(@{$modeldriver},"export ILOG_LICENSE_FILE=".$args->{"-cplex"});
}
make_path($args->{"-p"}."config") unless(-d $args->{"-p"}."config");
my $configFiles = "export FIGMODEL_CONFIG=".$args->{"-p"}."config/FIGMODELConfig.txt";
if (defined($args->{"-figconfig"})) {
    $configFiles .= ":".join(":",@{$args->{"-figconfig"}});
}
push(@{$queuedriver},$configFiles);
push(@{$modeldriver},$configFiles);
push(@{$queuedriver},"export ARGONNEDB=".$args->{"-d"}."ReactionDB/");
push(@{$modeldriver},"export ARGONNEDB=".$args->{"-d"}."ReactionDB/");
if (defined($args->{"-usr"}) && defined($args->{"-pwd"})) {
    push(@{$queuedriver},"export FIGMODEL_USER=".$args->{"-usr"});
    push(@{$modeldriver},"export FIGMODEL_PASSWORD=".$args->{"-pwd"});
}
push(@{$queuedriver},"perl ".$args->{"-p"}."lib/ModelSEED/FIGMODELscheduler.pl \$*");
push(@{$modeldriver},"perl ".$args->{"-p"}."lib/ModelSEED/ModelDriver.pl \$*");
printFile($args->{"-p"}."bin/ModelDriver".$extension,$modeldriver);
printFile($args->{"-p"}."bin/QueueDriver".$extension,$queuedriver);
chmod 0775, $args->{"-p"}."bin/ModelDriver".$extension;
chmod 0775, $args->{"-p"}."bin/QueueDriver".$extension;

#Creating envConfig.sh
my $script = fillEnvConfigTemplate($args->{"-p"}, $args->{"-d"});
printFile($args->{"-p"}."bin/envConfig".$extension, [$script]);
chmod 0775, $args->{"-p"}."bin/envConfig".$extension;

#Configuring databases
if(!defined("-dbhost")) {
    $args->{"-dbhost"} = $args->{"-p"}."data/ModelDB.db";
    make_path($args->{"-p"}."data/");
    print "No dbhost supplied. Configuring SQLite database at ".
    $args->{"-dbhost"}."\n";
}
if(!defined($args->{"-dbusr"})) {
    my $sqlite = `which sqlite3`;
    chomp $sqlite;
    if(!-f $sqlite) {
        print "Could not find installation of SQLite. Please install a copy!\n";    
    }
} else {
    my $mysql = `which mysql`;
    if(!-f $mysql) {
        print "Could not find installation of mySQL! Please install a copy!\n";
    }
}
foreach my $db (qw(ModelDB SchedulerDB UserDB)) {
    my $cmd = $args->{"-p"}."bin/ModelDriver".$extension." configureserver?".$db."?".$args->{"-dbhost"};
    $cmd .= (defined($args->{"-dbusr"})) ? "?".$args->{"-dbusr"} : "?";
    $cmd .= (defined($args->{"-dbpwd"})) ? "?".$args->{"-dbpwd"} : "?";
    $cmd .= "???";
    $cmd .= $args->{"-p"}."config/FIGMODELConfig.txt";
    warn $cmd;
    system($cmd);
}

sub printFile {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || die("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
        if (length($Item) > 0) {
            print $fh $Item."\n";
        }
    }
    close($fh);
}

sub loadFile {
    my ($Filename) = @_;
    my $DataArrayRef = [];
    if (open (INPUT, "<", $Filename)) {
        while (my $Line = <INPUT>) {
            chomp($Line);
            push(@{$DataArrayRef},$Line);
        }
        close(INPUT);
    }
    return $DataArrayRef;
}

sub fillEnvConfigTemplate {
    my ($root, $data) = @_;
    my $script = <<TPIRCS;
#!/usr/bin/sh
PATH=\${PATH}:$root/bin
PATH=\${PATH}:$root/lib/ModelSEED/ModelSEEDScripts/
export PATH

PERL5LIB=\${PERL5LIB}:$root/lib/PPO
PERL5LIB=\${PERL5LIB}:$root/lib/
PERL5LIB=\${PERL5LIB}:$root/lib/myRAST
PERL5LIB=\${PERL5LIB}:$root/lib/FigKernelPackages 
export PERL5LIB
TPIRCS
   return $script; 
}

$|=1; # ??

__DATA__

=head1 NAME

configureModelSEED - creates a configuration file for the ModelSEED enviorment

=head1 SYNOPSIS

configureModelSEED [options]

Options:

    --help                          brief help message
    -h
    -?
    --man                           returns this documentation
*   --installation_directory [-p]   location of ModelSEED installation directory
*   --data_directory [-d]           location of ModelSEED data directory
    --cplex                         location of CPLEX licence file
    --os                            operating system, "windows", "osx" or "linux"
    --username [--usr]               
    --figconfig 
    --dbhost
    --dbusr
    --dbpwd 

=cut
