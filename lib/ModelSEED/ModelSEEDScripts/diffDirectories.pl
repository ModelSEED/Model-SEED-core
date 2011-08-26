use strict;
$|=1;
 
if (!defined($ARGV[0]) || !defined($ARGV[1])) {
    print "Usage: perl diffDirectories.pl directoryOne directoryTwo\n";;
	exit(0);
}
if (!-d $ARGV[0]) {
	print "Could not find directory ".$ARGV[0]."\n";
	exit(0);	
}
if (!-d $ARGV[1]) {
	print "Could not find directory ".$ARGV[1]."\n";
	exit(0);	
}
my $copy = 0;
if (defined($ARGV[2]) && $ARGV[2] == 1) {
	$copy = 1;	
}

my @listOne = &RecursiveGlob($ARGV[0]);
my $path = $ARGV[0];
for (my $i=0; $i < @listOne; $i++) {
	my $newFilename = $listOne[$i];
	#print "File one:".$newFilename."\n";
	if ($newFilename !~ m/\/CVS\// && -e $newFilename) {
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($newFilename);
		my $firstTime = $mtime;
		$newFilename =~ s/$path//;
		if (!-e $ARGV[1].$newFilename) {
			print $listOne[$i].": new file in ".$ARGV[0]."\n";
			if ($copy == 1) {
				system('cp "'.$listOne[$i].'" "'.$ARGV[1].$newFilename.'"');
			}
		} else {
			($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($ARGV[1].$newFilename);
			if (($firstTime - $mtime) >= 60) {
				print $listOne[$i].": modified file in ".$ARGV[0]."\n";
				if ($copy == 1) {
					system('cp "'.$listOne[$i].'" "'.$ARGV[1].$newFilename.'"');
				}
			} 
		}
	}	
}

sub RecursiveGlob {
	my($path) = @_;
	my @FileList;
	## append a trailing / if it's not there
	$path .= '/' if($path !~ /\/$/);
	$path =~ s/\s/\\ /g;
	## loop through the files contained in the directory
	for my $eachFile (glob($path.'*')) {
		## if the file is a directory
		if( -d $eachFile) {
			## pass the directory to the routine ( recursion )
			push(@FileList,RecursiveGlob($eachFile));
		} else {
			push(@FileList,$eachFile);
		}
	}
	return @FileList;
}