#!/usr/bin/perl -w

########################################################################
# Script deletes old files from specified directory
# Author: Christopher Henry
# Author email: chenry@mcs.anl.gov
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2/29/2012
########################################################################
use strict;

my $directory;
if (defined($ARGV[0]) && -d $ARGV[0]) {
	$directory = $ARGV[0];
} else {
	print "delete-old-files (directory) (max age in hours)\n\n";
	exit(0);
}

my $maxage;
if (defined($ARGV[1]) && $maxage =~ m/^\d+$/) {
	$maxage = $ARGV[1];
} else {
	print "delete-old-files (directory) (max age in hours)\n\n";
	exit(0);
}

my @FileList = glob($directory."*");
for (my $i=0; $i < @FileList; $i++) {
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($FileList[$i]);
	if ((time() - $mtime) > 3600*$maxage) {
		if (-d $FileList[$i]) {
			print "Deleting ".$FileList[$i]."\n";
			system("rm -rf ".$FileList[$i]);
		} else {
			unlink($FileList[$i]);
		}
	}
}