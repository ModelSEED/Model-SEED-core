
# This is a SAS component

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#
package ProtSims;

use strict;
use Sim;
use Data::Dumper;
use Carp;
use gjoseqlib;
use DB_File;

use SeedAware;

my $blat_cmd = SeedAware::executable_for("blat");
my $blastall_cmd = SeedAware::executable_for("blastall");
my $formatdb_cmd = SeedAware::executable_for("formatdb");

#
# Need to call temps different names on each invocation -
# if a subprocess hung on windows, we get problems with
# "file in use" errors.
#
my $tmp_serial = 0;

sub blastP {
    my($q,$db,$min_hits,$use_blast) = @_;

    my(@q,@db);

    my $tmp_dir = SeedAware::location_of_tmp();

    my $tmp_suffix = $$ . "." . $tmp_serial++ . "." . time;

    my $qF;
    if (ref $q)
    {
	$qF = "$tmp_dir/query.$tmp_suffix";
	&gjoseqlib::print_alignment_as_fasta($qF,$q);
    }
    else
    {
	$qF = $q;
	if (-e $qF)
	{
	    @q = &gjoseqlib::read_fasta($qF);
	    $q = \@q;
	}
	else
	{
	    die "$qF is missing";
	}
    }

    my $db_lengths = {};

    my $dbF;
    if (ref $db)
    {
	$dbF = "$tmp_dir/db.$tmp_suffix";
	&gjoseqlib::print_alignment_as_fasta($dbF,$db);
	system($formatdb_cmd, '-i', $dbF);
	$db_lengths->{$_->[0]} = length($_->[2]) for @$db;
    }
    else
    {
	$dbF = $db;
	if (-e $dbF)
	{
	    if (! ((-e "$dbF.psq") && ((-M "$dbF.psq") < (-M $dbF))))
	    {
		system($formatdb_cmd, '-i', $dbF);;
	    }

	    my $db_tie;
	    if (-f "$dbF.lengths")
	    {
		$db_tie = tie %$db_lengths, 'DB_File', "$dbF.lengths", O_RDONLY, 0, $DB_BTREE;
		$db_tie or warn "Cannot tie $dbF.lengths: $!";
	    }
	    if (!defined($db_tie))
	    {
		if (open(my $dbfh, "<", $dbF))
		{
		    while (my($id, $def, $seq) = gjoseqlib::read_next_fasta_seq($dbfh))
		    {
			$db_lengths->{$id} = length($seq);
		    }
		    close($dbfh);
		}
		else
		{
		    warn "Cannot open $dbF: $!";
		}
	    }
	}
	else
	{
	    die "$dbF is missing";
	}
    }

    my $tmpF = "$tmp_dir/sim.out.$tmp_suffix";

    if ($use_blast)
    {
	open(my $fh, ">", $tmpF);
	close($fh);
    }
    else
    {
	my @cmd = ($blat_cmd, $dbF, $qF, "-prot", "-out=blast8", $tmpF);

	#
	# When running under FCGI, the system_with_redirect fails due to
	# the FCGI library redefining open.
	#

	my $rc;
	if (defined($ENV{FCGI_ROLE}))
	{
	    $rc = system(@cmd);
	}
	else
	{
	    $rc = system_with_redirect(\@cmd, { stdout => '/dev/null' } );
	}

	print STDERR "Blat returns $rc: @cmd\n";
	if ($rc != 0)
	{
	    warn "Blat run failed with rc=$rc\n";
	    open(my $fh, ">", $tmpF);
	    close($fh);
	}
    }

#     my $cmd = $use_blast ? "touch $tmpF" : "$blat_cmd $dbF $qF -prot -out=blast8 $tmpF > /dev/null";
#     #print STDERR "$cmd\n";
#     my $rc = system $cmd;
#     if ($rc != 0)
#     {
# 	die "ProtSims::blastP: blat run failed with rc=$rc: $cmd\n";
#     }

    my @sims1 = ();
    open(BLAT,"<$tmpF") || die "could not open $tmpF";
    my $sim = <BLAT>;
    while ($sim && ($sim=~ /^(\S+\t\S+)/))
    {
	my $pegs = $1;
	my @pieces = ();
	while ($sim && ($sim=~ /^((\S+\t\S+).*\S)/) && ($2 eq $pegs))
	{
	    push(@pieces,[split(/\t/,$1)]);
	    $sim = <BLAT>;
	}
	push(@sims1,&condense(\@pieces));
    }
    close(BLAT);
    unlink $tmpF;
    #print STDERR &Dumper(sims1 => \@sims1);

    my @rerun = ();
    my @sims  = ();
    my $qI    = 0;
    my $simI  = 0;
    while ($qI < @$q)
    {
	my $peg = $q->[$qI]->[0];
	#print STDERR "processing $peg\n";
	my $hits = 0;
	my $simI1 = $simI;
	while (($simI1 < @sims1) && ($sims1[$simI1]->[0] eq $peg)) 
	{
	    if (($simI1 == $#sims1) || ($sims1[$simI1]->[1] ne $sims1[$simI1+1]->[1]))
	    {
		$hits++;
	    }
	    $simI1++;
	}
	#print STDERR "hits=$hits min_hits=$min_hits\n";
	if ($hits >= $min_hits)
	{
	    push(@sims,@sims1[$simI..$simI1-1]);
	}
	else
	{
	    push(@rerun,$q->[$qI]);
	}
	$simI = $simI1;
	$qI++;
    }
    #print STDERR &Dumper(rerun => \@rerun);

    if (@rerun > 0)
    {
	my $tmpQ = "$tmp_dir/tmpQ.$tmp_suffix";
	&gjoseqlib::print_alignment_as_fasta($tmpQ,\@rerun);


	#
	# If we're under FCGI (and thus under the servers), and the loadavg is low, do a small parallel run.
	#

	my @par = ();
	if (defined($ENV{FCGI_ROLE}) && open(my $la, "/proc/loadavg"))
	{
	    my $l = <$la>;
	    chomp $l;
	    my @vals = split(/\s+/, $l);
	    my @procs = split(/\//, $vals[3]);
	    if ($vals[0] < 4 && $procs[0] < 8)
	    {
		@par = ("-a", 4);
	    }
	}

	
	# my $cmd = "$blastall_cmd -m 8 -i $tmpQ -d $dbF -FF -p blastp -e 1e-5";
	my @cmd = ($blastall_cmd,  '-m', 8, '-i', $tmpQ, '-d', $dbF, '-FF', '-p', 'blastp', '-e', '1e-5', @par);
	#print STDERR "$cmd\n";
	#open(BL, "$cmd|") or die "ProtSims::blastP: pipe to blast failed with $!: $cmd\n";

	#
	# It'd be nice to do this but windows doesn't support it.
	#
	#open(BL, "-|", @cmd) or die "ProtSims::blastP: pipe to blast failed with $!: @cmd\n";
	my $out_tmp = "$tmp_dir/blast_out.$tmp_suffix";
	push(@cmd, "-o", $out_tmp);
	#print STDERR "@cmd\n";
	my $rc = system(@cmd);
	if ($rc != 0)
	{
	    warn "Error rc=$rc running blast: @cmd\n";
	}
	else
	{
	    if (open(BL, "<", $out_tmp))
	    {
		while (<BL>)
		{
		    chomp;
		    push @sims, [ split(/\s+/, $_) ];
		}
		#my @blastout = map { chomp; [split(/\s+/,$_)] } <BL>;
		# push(@sims,@blastout);
		close(BL);
	    }
	}
	unlink $out_tmp;
	unlink $tmpQ;
    }

    my %lnQ   = map { $_->[0] => length($_->[2]) } @$q;

    @sims = map { push(@$_, $lnQ{$_->[0]}, $db_lengths->{$_->[1]}); bless($_,'Sim') } @sims;

    if ($qF      eq "$tmp_dir/query.$tmp_suffix")   { unlink $qF  }
    if ($dbF     eq "$tmp_dir/db.$tmp_suffix")      { unlink($dbF,"$dbF.psq","$dbF.pin","$dbF.phr") }
    return sort { ($a->id1 cmp $b->id1) or ($a->psc <=> $b->psc) or ($a->id2 cmp $b->id2) } @sims;
}

sub condense {
    my($pieces) = @_;

    my $best_sc = $pieces->[0]->[10];
    my @sims = sort { ($a->[6] <=> $b->[6]) } @$pieces;
    while (@sims > 1)
    {
	my $gap1 = $sims[1]->[6] - $sims[0]->[7];
	my $gap2 = $sims[1]->[8] - $sims[0]->[9];
	my $diff = abs($gap1 - $gap2);
	if (($gap1 <= 300) && ($gap2 <= 300) && ($diff <= (0.1 * &min($gap1,$gap2))))
	{
	    $sims[0]->[7] = $sims[1]->[7];
	    $sims[0]->[9] = $sims[1]->[9];
	}
	splice(@sims,1,1);
    }
    $sims[0]->[10] = $best_sc;
    return $sims[0];
}

sub min {
    my($x,$y) = @_;
    return ($x <= $y) ? $x : $y;
}

1;
