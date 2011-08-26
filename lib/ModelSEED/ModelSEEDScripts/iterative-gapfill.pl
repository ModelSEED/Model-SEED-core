#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use XML::LibXML;
use File::Temp qw(tempfile);

exit();
my ($rootDir) = @_;
if(not defined($rootDir)) {
    $rootDir = getcwd;
}        
$rootDir .= "/" unless($rootDir =~ /\/$/); 
unless(-d $rootDir) {
    warn "Could not find directory $rootDir!\n";
    exit();
}

# CRITICAL GLOBAL SETTINGS #
my $lpFilename = $rootDir . "problem.lp";
my $cplexBin = "/gpfs/pads/projects/CI-DEB000002/devoid/";
my $logFilename = "log.lp";
############################
unless(-e $cplexBin){
    warn "Could not find CPLEX binary file $cplexBin\n";
    exit();
} 
unless(-e $lpFilename){
    warn "Could not find problem file $lpFilename\n";
    exit();
} 
    
my ($objective, $target) = parse_problem($lpFilename);
my ($tmpFh, $solutionFilename) = 
    tempfile('solution-XXXXXX', DIR => $rootDir);
close($tmpFh);
my $cmdFilename = run_cplex({ cplex => $cplexBin,
                              problem => $lpFilename,
                              dir => $rootDir,
                              output => $solutionFilename});
my $onVariables = parse_solution($solutionFilename, $objective);
my ($gapfilled, $active) = sort_variables($onVariables, $objective, 0.00001);
write_to_log($target, $gapfilled, $active, $logFilename, $cmdFilename);
exit();


sub sort_variables {
    my ($onVars, $objective, $cuttoff) = @_;
    my $gapfilled = [];
    my $active = [];
    for my $var (@$onVars) {
        if(defined $objective->{$var} &&
            $var > $cuttoff) {
            push(@$gapfilled, $var);
        } elsif(defined $objective->{$var} &&
            $var < (-1 * $cuttoff) ) {
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
    open(my $fh, ">>", $logfile) || die($@);
    my $sep = ',';
    print $fh $inactive_rxn . "\t" . join($sep, @$gapfilled_rxns) . "\t" .
        join($sep, @$active_rxns) . "\t" . $solfile . "\n";
    close($fh);
}

# Given a solution filename, a set of objective variables, and optionally
# a cutoff; parse the solution results and return the set of variables
# that are (a) set to > cuttof (default: 0.5) and (b) in the set of
# objective variables.
sub parse_results {
    my ($solution_file, $objectives, $cuttoff) = @_;
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

sub do_cplex {
    my ($args) = @_;
    # args contains: problem, dir, cplex, outputfile
    my ($OUTPUT, $filename) = tempfile('cplex-cmd-XXXXXX',
                                       dir => $args->{dir});
    print $OUTPUT "read ".$args->{problem}."\n";
    print $OUTPUT "set mip display 0\n";
    print $OUTPUT "set mip tolerances integrality 1e-8\n";
    print $OUTPUT "set simplex tolerances feasibility 1e-8\n";
    print $OUTPUT "set timelimit 86400\n";
    print $OUTPUT "set mip limits treememory 1000\n";
    print $OUTPUT "set workmem 1000\n";
    print $OUTPUT "set workdir ".$args->{dir}."\n";
    print $OUTPUT "set threads 0\n";
    print $OUTPUT "mipopt\n";
    print $OUTPUT "write ".$args->{outputfile}." sol\n";
    print $OUTPUT "quit\n";
    close($OUTPUT);
    system("cat $filename | ".$args->{cplex});
    return $filename;
}
