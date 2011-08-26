#!/usr/bin/env perl

use strict;
use Cwd;
use Cwd qw(abs_path);
use File::Temp qw(tempfile);
use Getopt::Long;
use XML::LibXML;

my $usage = <<End_of_Usage;

Usage: do-gapfill.pl [-help]
                     [-cplex cplex_bin]
                     [-d     problem_dir]
                     [-exp   export_dir]
                     [-li    cplex_license]
                     [-log   log.txt]
                     [-mem   n_MB]
                     [-time  n_seconds]
                     [-nt    num_threads]
                     [-p     problem.lp]
                     [-ld    solution.out]   [problem_dir]

End_of_Usage

my ($help, $cwd, $time, $memory, $numThreads, $rootDir, $exportDir,
    $cplexLicense, $cplexBin, $lpFilename, $logFilename, $solutionFilename);

GetOptions("h|help"        => \$help,
           "d|root=s"      => \$rootDir,
           "exp=s"         => \$exportDir,
           "cplex=s"       => \$cplexBin,
           "li|license=s"  => \$cplexLicense,
           "log=s"         => \$logFilename,
           "mem=i"         => \$memory,
           "time=i"        => \$time,
           "nt=i"          => \$numThreads,
           "p|lp=s"        => \$lpFilename);

$rootDir ||= shift @ARGV;

$help || !$lpFilename && !$rootDir and die $usage;

$rootDir          ||= ".";
$cplexLicense     ||= "/home/devoid/access.ilm";
$cplexBin         ||= "/home/fangfang/bin/cplex";
$logFilename      ||= "log.txt";
$lpFilename       ||= "problem.lp";
$solutionFilename ||= "cplex.sol";

$cwd                = getcwd();
$rootDir            = abs_path($rootDir);
$lpFilename         = -s $lpFilename ? abs_path($lpFilename) : $rootDir."/".$lpFilename;
$logFilename        = $rootDir."/".$logFilename;
$solutionFilename   = $rootDir."/".$solutionFilename;

-s $lpFilename   or die "Could not find problem file $lpFilename";
-x $cplexBin     or die "Could not execute CPLEX binary file $cplexBin";
-s $cplexLicense or die "Could not find CPLEX license file $cplexLicense";

verify_dir($rootDir);

$ENV{'ILOG_LICENSE_FILE'} = $cplexLicense;

exit if -s $solutionFilename && -s $logFilename;

my ($objective, $target) = parse_problem($lpFilename);
# my (undef, $solutionFilename) = tempfile('solution-XXXXXX', DIR => $rootDir, OPEN => 0);

unless (-s $solutionFilename) {
    run_cplex({ cplex => $cplexBin,
                dir       => $rootDir,
                export    => $exportDir,
                problem   => $lpFilename,
                memory    => $memory,
                threads   => $numThreads,
                time      => $time,
                out       => $solutionFilename});
}

my $onVariables          = parse_results($solutionFilename, $objective);
my ($gapfilled, $active) = sort_variables($onVariables, $objective, 0.00001);

write_to_log($target, $gapfilled, $active, $logFilename, $solutionFilename);

if ($exportDir) {
    print getcwd();
    my $prefix = $rootDir;  $prefix =~ s|.*/||g;
    my $cplexOut = "$rootDir/cplex.out";
    my @files = ($solutionFilename, $logFilename, $cplexOut);
    for (@files) {
        my $filename = $_;
           $filename =~ s|.*/||g; 
           $filename = $prefix.".".$filename;
        system "cp $_ $exportDir/$filename" if -e $_;
    }
}

sub sort_variables {
    my ($onVars, $objective, $cuttoff) = @_;
    my $gapfilled = [];
    my $active = [];
    for my $var (@$onVars) {
        if(defined $objective->{$var} &&
            $objective->{$var} > $cuttoff) {
            push(@$gapfilled, $var);
        } elsif(defined $objective->{$var} &&
            $objective->{$var} < (-1 * $cuttoff) ) {
            push(@$active, $var);
        }
    }
    return ($gapfilled, $active);
}

sub parse_problem {
    my ($filename) = @_;
    open (my $fh, "<", $filename) || die($@);
    my $objective = [];
    my $objectives = {};
    my ($forcedRxn, $prevLine, $objectiveDone) = undef;
    while(<$fh>) {
        chomp $_;
        if(!$objectiveDone && $_ =~ /obj: (.*)$/) {
           push(@$objective, split(/\s+/, $1));
        } elsif($_ =~ /^Subject To/) { 
            $objectiveDone = 1;
        } elsif(!$objectiveDone && scalar(@$objective) > 0) {
            push(@$objective, split(/\s+/, $_));
        } elsif($_ =~ /^Bounds/) {
           if($prevLine and $prevLine =~ /(rxn\d\d\d\d\d)/) {
                $forcedRxn = $1;
            }
        }
        $prevLine = $_;
    }
    close($fh);
    my $i = 0;
    while($i < scalar(@$objective)) {
        if($objective->[$i] eq '') {
            $i++;
        }
        my ($sign, $coff, $var) = undef;
        if($i != 0) {
            $sign = $objective->[$i];
        } else {
            if($objective->[$i] =~ /-/) {
                $sign = $objective->[$i];
            } elsif($objective->[$i] =~ /\+/) {
                $sign = $objective->[$i];
            } else {
                $sign = "+";
                $i = -1;
            }
        }
        $coff = $objective->[$i+1];
        $var  = $objective->[$i+2];
        $objectives->{$var} = $sign . $coff;
        $i = $i + 3;
    }
    return ($objectives, $forcedRxn);
}

# Appends lines to a specified logfile. Main columns are 
# write_to_log("rxn00001", ["rxn12345", "rxn6789"],
#      ["rxn10000"], "logfile.txt", "tmp-sol23r2nf");
sub write_to_log {
    my ($inactive_rxn, $gapfilled_rxns, $active_rxns, $logfile, $solfile) = @_;
    my $sep1 = "\t";
    my $sep2 = ",";
    open(LOG, ">", $logfile) or die "Could not write to $logfile";
    print LOG join($sep1, $inactive_rxn, join($sep2, @$gapfilled_rxns), join($sep2, @$active_rxns), $solfile)."\n";
    close(LOG);
}

# Given a solution filename, a set of objective variables, and optionally
# a cutoff; parse the solution results and return the set of variables
# that are (a) set to > cuttof (default: 0.5) and (b) in the set of
# objective variables.
sub parse_results {
    my ($solution_file, $objectives, $cuttoff) = @_;
    -s $solution_file or die "No solution found: $solution_file";
    $cuttoff = 0.5 if not defined $cuttoff;
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file($solution_file);
    my @constraints = $doc->getElementsByTagName("variable");
    my $onVariables = [];
    foreach my $constraint (@constraints) {
        my $name = $constraint->getAttribute('name');
        my $value = $constraint->getAttribute('value');
        next unless defined $name and defined $value;
        next unless defined $objectives->{$name};
        next unless $value > $cuttoff;
        push(@$onVariables, $name)
    }
    return $onVariables;
}

sub run_cplex {
    my ($args) = @_;
    # args contains: problem, dir, cplex, outputfile
    for (qw(cplex.log)) { unlink $_ if -e $_ }

    my $cplex   = $args->{cplex};
    my $dir     = $args->{dir};
    my $problem = $args->{problem};
    my $out     = $args->{out}     || 'cplex.sol';
    my $threads = $args->{threads} || 0;
    my $workmem = $args->{memory}  || 1000;
    my $treemem = $args->{memory}  || 1000;
    my $maxtime = $args->{time}    || 36000;
    my $cwd     = getcwd();

    chdir($dir);

    # my ($OUTPUT, $filename) = tempfile('cplex-cmd-XXXXXX');
    my $filename = 'cplex.cmd';
    my $OUTPUT;
    open($OUTPUT, ">$filename") or die "Could not open $filename";

    print $OUTPUT "read $problem\n";
    print $OUTPUT "set mip display 0\n";
    print $OUTPUT "set mip tolerances integrality 1e-8\n";
    print $OUTPUT "set simplex tolerances feasibility 1e-8\n";
    print $OUTPUT "set timelimit $maxtime\n";
    print $OUTPUT "set mip limits treememory $treemem\n";
    print $OUTPUT "set workmem $workmem\n";
    print $OUTPUT "set workdir $dir\n";
    print $OUTPUT "set threads $threads\n";
    print $OUTPUT "mipopt\n";
    # print $OUTPUT "write $out sol\n";
    print $OUTPUT "write $out\n";
    print $OUTPUT "quit\n";

    close($OUTPUT);

    # my (undef, $errFilename) = tempfile('cplex-err-XXXXXX', OPEN => 0);
    # my (undef, $outFilename) = tempfile('cplex-out-XXXXXX', OPEN => 0);
    my $outFilename = 'cplex.out';
    my $errFilename = 'cplex.err';

    system("$cplex <$filename 2> $errFilename >$outFilename");

    chdir($cwd);

    return $filename;
}


sub verify_dir {
    my ($dirName) = @_;
    $dirName =~ s#/$##;
    if (! -d $dirName) {
        if ($dirName =~ m#(.+)/[^/]+$#) {
            verify_dir($1);
        }
        mkdir $dirName, 0755;
    }
}
