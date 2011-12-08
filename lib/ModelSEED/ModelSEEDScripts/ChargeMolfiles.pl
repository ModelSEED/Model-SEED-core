#!/usr/bin/perl -w
use strict;
use IPC::Open3;

my $SourcePath = $ARGV[0];
my $DestinationPath = $ARGV[1];
my $MarvinBeansPath = $ARGV[2];
$MarvinBeansPath .= "bin/cxcalc";

if(!$SourcePath || !-d $SourcePath || !$DestinationPath || !-d $DestinationPath || !$MarvinBeansPath){
    usage();
    exit(0);
}

if(!-f $MarvinBeansPath){
    usage();
    print STDERR "Cannot find cxcalc executable, double-check path for MarvinBeans software:\n".$MarvinBeansPath."\n";
    exit(0);
}

opendir(my $dh, $SourcePath) || die "can't opendir $SourcePath: $!";
my %Files = map {$SourcePath.$_=>1} grep { /\.mol$/ } readdir($dh);
closedir $dh;

my($wtr, $rdr, $err, $pid);
use Symbol 'gensym'; $err = gensym;
my ($test,$out,$rdrstr,$errstr,$KEGG);

my $Command = $MarvinBeansPath.' -N hi majorms -H 7';

foreach my $file(sort keys %Files){
    $KEGG=substr($file,rindex($file,'/')+1,-4);
    print $KEGG,"\n";

    #Run generating Mol files
    $pid=open3($wtr, $rdr, $err,$Command." -f mol:-a ".$file);
    waitpid($pid, 0);

    $rdrstr="";
    while(<$rdr>){
	$rdrstr.=$_;
    }
    $errstr="";
    while(<$err>){
	$errstr.=$_;
    }

    if(length($rdrstr)>0){
	open(OUT, "> ".$DestinationPath.$KEGG.".mol");
	print OUT $rdrstr;
	close OUT;
    }

    if(length($errstr)>0){
	open(OUT, "> ".$DestinationPath.$KEGG.".mol.err");
	print OUT $errstr;
	close OUT;
    }

    #Run generating InChI files
    $pid=open3($wtr, $rdr, $err,$Command." -f inchi:-a ".$file);
    waitpid($pid, 0);

    $rdrstr="";
    while(<$rdr>){
	$rdrstr.=$_;
    }
    $errstr="";
    while(<$err>){
	$errstr.=$_;
    }

    if(length($rdrstr)>0){
	open(OUT, "> ".$DestinationPath.$KEGG.".inchi");
	print OUT $rdrstr;
	close OUT;
    }

    if(length($errstr)>0){
	open(OUT, "> ".$DestinationPath.$KEGG.".inchi.err");
	print OUT $errstr;
	close OUT;
    }
}

sub usage {
    print "./ChargeMolfiles <directory of mol files> <Directory for output files> <Path for MarvinBeans Software (ie ~/Software/MarvinBeans/)>\n";
}

#For the record:
#
#KEGG MB Errors:
#   1  Calculation result is not defined for molecules with pseudo atoms. --> OMITTED
#  13  Inconsistent molecular structure.                                  --> An attempt was made to fix these
# 196  Calculation result is not defined for molecules with SRU S-groups. --> OMITTED for now
#1130  Calculation result is not defined for query molecules              --> OMITTED
#
#KEGG InChI Errors:
#   1 Accepted unusual valence(s): As(4)  --> These are ignored
#   1 Accepted unusual valence(s): Fe(1)  --> These are ignored
#   1 Accepted unusual valence(s): N+1(5) --> These are ignored
#   1 Accepted unusual valence(s): V-3(8) --> These are ignored
#   2 Charges neutralized                 --> These are ignored (Double-checked)
#   4 Accepted unusual valence(s): Co(1)  --> These are ignored
#   9 Charges were rearranged             --> These are ignored
#  16 Salt was disconnected               --> These are ignored
#  20 Ambiguous stereo: bond(s)           --> These are ignored (Checked: No duplicate InChI strings here)
# 118 Metal was disconnected              --> These are ignored
#1630 Omitted undefined stereo            --> OMITTED (Duplicate InChI strings create problems)
#6355 Proton(s) added/removed             --> These are ignored
#
#
#MetaCyc MB Errors:
#  67  Inconsistent molecular structure.
# 300  Calculation result is not defined for query molecules
