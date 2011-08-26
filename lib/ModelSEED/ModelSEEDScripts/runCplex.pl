#!/usr/bin/perl -w

########################################################################
# Driver script that runs the cplex solver on an input lp file
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 8/26/2008
########################################################################

use strict;
$|=1;
if (!defined($ARGV[3]) || $ARGV[0] eq "help") {
    print 'Usage: perl runCplex.pl "working directory" "LP filename" "solution output filename" "cplex executable"'."\n";
	exit(0);
}
my $filename = $ARGV[0]."tempcplex.cmd";
open (OUTPUT, ">$filename");
print OUTPUT "read ".$ARGV[1]."\n";
print OUTPUT "set mip display 0\n";
print OUTPUT "set mip tolerances integrality 1e-8\n";
print OUTPUT "set simplex tolerances feasibility 1e-8\n";
print OUTPUT "set timelimit 86400\n";
print OUTPUT "set mip limits treememory 1000\n";
print OUTPUT "set workmem 1000\n";
print OUTPUT "set workdir ".$ARGV[0]."\n";
print OUTPUT "set threads 0\n";
print OUTPUT "mipopt\n";
print OUTPUT "write ".$ARGV[2]." sol\n";
print OUTPUT "quit\n";
close(OUTPUT);
#print "cat ".$ARGV[0]."tempcplex.cmd | ".$ARGV[3]."\n";
system("cat ".$ARGV[0]."tempcplex.cmd | ".$ARGV[3]);