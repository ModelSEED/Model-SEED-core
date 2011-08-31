# -*- perl -*-

# This is a SAS component.

########################################################################
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
########################################################################

package FS_RAST;
use SeedEnv;
use SeedAware;

BEGIN
{
    my $have_tracer = 0;
    eval { require Tracer; Tracer->import(); $have_tracer = 1; };
    if (!$have_tracer)
    {
	eval { require MinimalTracer; MinimalTracer->import(); print "loaded minimal\n"; };
    }
}

use File::Path 'rmtree';

use gjoseqlib;
use strict;
#
# FS_RAST is going into SAS which can't rely on Tracer. We're taking a shot
# at making SeedAware init a minimal emulation of the interface.
#
#use Tracer;
&ETracing;    ### initializes Tracing
#
# export TRACING=RossO     <<< to turn on tracing, do this from command line
# trace 3

use find_special_proteins;

use Data::Dumper;
use Carp;

#===============================================================================
#  Use a FIGfam (set of representatives and set of family members) as the basis
#  for searching for an instance in a given set of contigs.  The thing that makes
#  it special is that it is tolerant of frameshifts.
#
#      @instances  = find_and_correct( \%params )
#
#  Required parameters:
#
#      contigs    => \@contigs
#      family     => \@family_members
#
#  Optional paramaters:
#
#      reps       => \@representatives
#      is_init    => \@initiator_triplets                ( D = [ATG,GTG] )
#      is_alt     => \@second_choice_initiator_triplets  ( D = [TTG] )
#      is_term    => \@terminator_triplets               ( D = [TAA,TAG,TGA] )
#      tmp        =>  $directory           directory for tmp_dir
#      tmp_dir    =>  $directory           directory for temporary files
#
#  RETURNS:  a list of hashes.  Each hash is an "instance" with
#         $instance->{location}    => location
#         $instance->{translation} => translation
#         $instance->{annotation}  => annotation describing alterations
#         $instance->{genomes}     => pointer to a list of the closest genomes [unsorted, up to 10]
#==================================================================================================

sub find_and_correct
{
    my ( $params ) = @_;
    my @instances = ();

    my ( $tmp_dir, $save_tmp ) = &temporary_directory( $params );

    my $contigs = $params->{ contigs }
        or return ();

    ( ref( $contigs ) eq 'ARRAY' ) and ( @$contigs )
        or return ();

    #  Make a hash to find contig data by id:
    my %contig = map { $_->[0] => $_ } @$contigs;

    my $family = $params->{ family }
        or return ();

    ( ref( $family ) eq 'ARRAY' ) and ( @$family )
        or return ();

    my $reps = $params->{ reps };
    if (! $reps) { $reps = $params->{reps} = $family }

    ( ref( $reps ) eq 'ARRAY' ) and ( @$reps )
        or return ();

    my $suffix = $$ . "_" . sprintf( "%09d", int( 1e9 * rand() ) );
    my $contig_file = "$tmp_dir/contigs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $contig_file, $contigs );
    -f $contig_file or return ();

    my $family_file = "$tmp_dir/family_$suffix";
    gjoseqlib::print_alignment_as_fasta( $family_file, $family );
    -f $family_file or return ();
    $params->{family_file} = $family_file;

    my $reps_file = "$tmp_dir/reps_$suffix";
    gjoseqlib::print_alignment_as_fasta( $reps_file, $reps );
    -f $reps_file or return ();

    my($formatdb,$blastall);
    if (! ($formatdb = $params->{formatdb}))
    {
	$formatdb   = executable_for("formatdb");
	$params->{formatdb} = $formatdb;
    }

    if (! ($blastall = $params->{blastall}))
    {
	$blastall   = executable_for("blastall");
	$params->{blastall}  = $blastall;
    }

    #system "cd '$tmp_dir'; $formatdb -p f -i 'contigs_$suffix'; $formatdb -p t -i 'family_$suffix'";

    my @blast_out = run_gathering_output($blastall, '-i',  $reps_file, '-d', $contig_file, 
					 qw(-FF -p tblastn -m 8 -e 1.0e-5));
    
    my @search_out = map { $_ =~ /^(\S+)\t(\S+)\t(\S+\t){4}(\d+)\t(\d+)\t(\d+)\t(\d+)/; [$1,$2,$4,$5,$6,$7] }
    			 @blast_out;

#    print STDERR &Dumper("blast", \@blast_out, \@search_out);

 #   print STDERR &Dumper(\@search_out);
    my @groups = &cluster_blast(\@search_out);

    my $group;
    my %seen;
    foreach $group (@groups)
    {
	my($loc,$translation,$genomes,$annotation,$complete_contig) = 
	    &process_group($params,$group,$family_file,$contigs);
	if (defined($loc) && (! $seen{$loc}))
	{
	    $seen{$loc} = 1;

	    my $instance = {};
	    $instance->{location} = $loc;
	    $instance->{translation} = $translation;
	    $instance->{genomes} = $genomes;
	    $instance->{annotation} = $annotation ? $annotation : "";
	    push(@instances,$instance);
	}
    }
    rmtree($tmp_dir) if ! $save_tmp;
    return @instances;
}

sub process_group {
    my($params,$group,$familyDB,$contigs) = @_;
    my($i);

    my @search_out = @$group;
    my $contig = $search_out[0]->[1];
    my $first_piece = shift @search_out;
    my @pieces = ($first_piece);

    my $piece;
    my $p1;
    for ($p1=0; ($p1 < @search_out) && (! &close_to_picked(\@pieces,$search_out[$p1])); $p1++) {}
    while ($p1 < @search_out)
    {
	push(@pieces,splice(@search_out,$p1,1));
	for ($p1=0; ($p1 < @search_out) && (! &close_to_picked(\@pieces,$search_out[$p1])); $p1++) {}
    }
    @pieces = &remove_embedded(\@pieces);

###
### You have now taken the best hit piece and find others to tack on the ends.
###
    my $minD = 1000000000;
    my $minP = 100000;
    my $maxD = 0;
    my $maxP = 0;
    foreach $piece (@pieces)
    {
	$minD = &SeedUtils::min($minD,$piece->[4],$piece->[5]);
	$maxD = &SeedUtils::max($maxD,$piece->[4],$piece->[5]);

	$minP = &SeedUtils::min($minP,$piece->[2],$piece->[3]);
	$maxP = &SeedUtils::max($maxP,$piece->[2],$piece->[3]);
    }

###
### We need to now extract the boundaries for the region to be blasted back against all of the members of the family
###
    my $reps = $params->{ reps };
    my $start_adj = 3 * ($minP - 1) + 1000;
    for ($i=0; ($i < @$reps) && ($reps->[$i]->[0] ne $pieces[0]->[0]); $i++) {}
    my $end_adj = ((length($reps->[$i]->[2]) - $maxP) * 3) + 1000;
    Trace &Dumper([$contig,"minD=$minD","maxD=$maxD","minP=$minP","maxP=$maxP","start_adjust=$start_adj","end_adjust=$end_adj"]) if T(3);

    for ($i=0; (($i < @$contigs) && $contigs->[$i]->[0] ne $contig); $i++) {}

    if ($i < @$contigs)
    {
	my $complete_contig = $contigs->[$i]->[2];
	my $start = &SeedUtils::max(1,($minD-$start_adj));
	my $end   = &SeedUtils::min(length($contigs->[$i]->[2]),$maxD+$end_adj);
	my $dna = substr($contigs->[$i]->[2],$start-1,($end+1-$start));
        my $frag = [$contig,$start,$end,$dna];     			      
        Trace &Dumper(['fragment from tblastn: ',$frag]) if T(3);
###
### $frag is a 4-tuple that describes the piece of DNA from the contig that we will use to blast against
### members of the family
###
	return (&best_match_in_family($params,$frag),$complete_contig);
    }
    return undef;
}

sub make_ali {
    my($untranslated,$translation,$tmp_dir) = @_;

    my $tmpD = "$tmp_dir/dna$$";
    my $tmpP = "$tmp_dir/prot$$";
    my $tmpA = "$tmp_dir/ali$$";
    
    my $alignment = "";
    open(TMP,">$tmpD") || die "could not open $tmpD";
    print TMP ">dna\n$untranslated\n";
    close(TMP);

    open(TMP,">$tmpP") || die "could not open $tmpP";
    print TMP ">prot\n$translation\n";
    close(TMP);

    my $matrix = "$FIG_Config::global/nap_matrix";
    if (! -f $matrix)
    {
	$matrix = "$tmp_dir/nap_matrix";
	write_nap_matrix($matrix);
    }
    
    system_with_redirect(executable_for("nap"),
			 $tmpD, $tmpP, 9, $matrix, 10, 1,
		         { stdout => "/dev/null",
			   stderr => $tmpA });

    # system "nap $tmpD $tmpP 9 $FIG_Config::global/nap-matrix 10 1 > /dev/null 2> $tmpA";
    my @tmp = split("\n", slurp_input($tmpA));
    splice(@tmp,0,4);
    $alignment .= join("\n",@tmp) . "\n";
    unlink($tmpD,$tmpP,$tmpA);
    return $alignment;
}

sub best_match_in_family {
    my($params,$frag) = @_;

#   print STDERR &Dumper($frag);
    my $tmp_dir = $params->{tmpdir};
    my $save_tmp = 1;

    if (! $tmp_dir)
    {
	( $tmp_dir, $save_tmp ) = &temporary_directory( $params );
    }

    if (! $params->{ family_file })
    {
	my $family = $params->{ family }
           or return undef;

	( ref( $family ) eq 'ARRAY' ) and ( @$family )
	    or return undef;
	my $suffix = $$ . "_" . sprintf( "%09d", int( 1e9 * rand() ) );
	my $family_file = "$tmp_dir/family_$suffix";
	gjoseqlib::print_alignment_as_fasta( $family_file, $family );
	-f $family_file or return undef;
	$params->{family_file} = $family_file;

	my($formatdb,$blastall);
	if (! ($formatdb = $params->{formatdb}))
	{
	    $formatdb   = executable_for("formatdb");
	    $params->{formatdb} = $formatdb;
	}
	my $rc = system($formatdb, '-l', "$tmp_dir/formatdb.log", "-p", "t", "-i", $family_file);
	if ($rc != 0)
	{
	    die "Error running formatdb rc=$rc\n";
	}
	
#	system "cd '$tmp_dir'; $formatdb -p t -i 'family_$suffix'";

	if (! ($blastall = $params->{blastall}))
	{
	    $blastall   = executable_for("blastall");
	    $params->{blastall}  = $blastall;
	}
    }
    else
    {
	$params->{family} = [&gjoseqlib::read_fasta($params->{ family_file })];
    }
    my $tmpF = "$tmp_dir/fragment.fasta";
    my $dna = $frag->[3];
    open(DNA,">$tmpF") || die "could not open $tmpF";
    print DNA ">frag\n$dna\n";
    close(DNA);

    my $family_file = $params->{family_file};
    my $blastall    = $params->{blastall};

#    my @tmp = `$blastall -i $tmpF -d $family_file -FF -p blastx -m 8 -g F -e 1.0e-5`;
#    print STDERR join("",@tmp),"\n";

    my @blast_out = run_gathering_output($blastall, "-i", $tmpF, "-d", $family_file,
					 qw(-FF -p blastx -m 8 -g F -e 1.0e-5));

    my @search_out = map { $_ =~ /^(\S+)\t(\S+)\t(\S+\t){4}(\d+)\t(\d+)\t(\d+)\t(\d+)/; [$2,$1,$6,$7,$4,$5] }
    			@blast_out;


#                    `$blastall -i $tmpF -d $family_file -FF -p blastx -m 8 -g F -e 1.0e-10`;

#    print Dumper("blast", \@blast_out, \@search_out);


###
### We just used blastx to try to find the most similar members from the family
###
    my $genomes = {};
    my $sim;
    for (my $simI = 0; ($simI < @search_out) && ($simI < 10); $simI++)
    {
	$sim = $search_out[$simI];
	$genomes->{&SeedUtils::genome_of($sim->[0])}++;   ### this just records the most similar genomes
    }

    my @groups = &cluster_blast(\@search_out);

###
### @search_out now has the hits against the best member of the family
###

    my($groupI,$loc,$pieces_of_untrans,$untranslated,$translation,$annotation);
    $groupI = 0;
    while (($groupI < @groups) && (! defined($loc)))
    {
	my $group = $groups[$groupI];

	my @search_out = @$group;
	my $first_piece = shift @search_out;
	my @pieces = ($first_piece);
	my $p1;
	for ($p1=0; ($p1 < @search_out) && (! &close_to_picked(\@pieces,$search_out[$p1])); $p1++) {}
	while ($p1 < @search_out)
	{
	    push(@pieces,splice(@search_out,$p1,1));
	    for ($p1=0; ($p1 < @search_out) && (! &close_to_picked(\@pieces,$search_out[$p1])); $p1++) {}
	}
	@pieces = &remove_embedded(\@pieces);
	my @sorted = sort { $a->[2] <=> $b->[2] } @pieces;
###
### again we piece together the set of (perhaps) frameshifted pieces (sorted by the beginning protein position)
###
# 	print STDERR &Dumper(['after removing embedded',\@sorted]); 

	if (&ok_seq(\@sorted) && 
	    &extend_to_start_stop(\@sorted,$frag,$params))
	{
#	    print STDERR "seq is ok\n";
	    my($contig,$beg,$end,$dna) = @$frag;
	    my @locs = &make_loc(\@sorted,$frag,&stops($params));
	    $loc = join(",",map { join("_",($contig,@$_)) } &shift_coords(\@locs,$beg,$end));;
#	    print STDERR "loc=$loc\n";
	    ($pieces_of_untrans,$untranslated,$translation) = &make_translation(\@locs,$frag);
#
#           The untranslated is now chunks corresponding to the translation pieces.
#           I am now adding just the DNA of the region, since that is what should be
#           aligned
#
	    my $begD = $sorted[0]->[4];
	    my $endD = $sorted[$#sorted]->[5];
	    my $untranslated_region = ($begD < $endD) ? 
                                      substr($frag->[3],$begD-1,($endD-$begD)+1) :
		                      &SeedUtils::reverse_comp(substr($frag->[3],$endD-1,($begD-$endD)+1));
#
	    $annotation = "";

	    if (@locs > 1)
	    {
#		print STDERR "we tried to fix a frameshift\n";
		my $n = @sorted - 1;
		$annotation = "We believe that there may have been frameshifts and embedded stop codons, " .
			      " and we attempted to correct the translation.\n  Hence, the translation does not agree perfectly with the corresponding region of DNA.\n\n";
		my $alignment = &make_ali($untranslated_region,$translation,$tmp_dir);
		$annotation .= $alignment;
		my $guide_peg = $sorted[0]->[0];
		$annotation .= "\n==========\nNow we show an alignment against a similar protein ($guide_peg):\n\n";
#        	print STDERR "ANNO: $annotation\n";

		my $family = $params->{family};
		my $i;
		for ($i=0; ($i < @$family) && ($family->[$i]->[0] ne $guide_peg); $i++) {}
		if ($i == @$family)
		{
#		    print STDERR &Dumper(['family',$family,$i]);
		    die "this should not be possible";
		}
		my $trans = $family->[$i]->[2];
		if (abs(length($trans) - length($translation)) > 30) 
		{ 
#		    print STDERR &Dumper(['bad trans',$trans,$translation]);
		    undef $loc ;
		}
		else
		{
		    $alignment = &make_ali($untranslated_region,$trans, $tmp_dir);
		    $annotation .= $alignment;
		}
	    }
	}
	$groupI++;
    }
    rmtree($tmp_dir) if ! $save_tmp;
#   if ($loc) { print STDERR &Dumper($loc) }
    return $loc ? ($loc,$translation,[keys(%$genomes)],$annotation) : undef;
}

sub stops {
    my($param) = @_;
    my($code);

    if     ($param->{is_term}) { return $param->{is_term} }
    elsif  (($code = $param->{code}) && ($code == 4)) { return ['taa','tag'] }
    return ['taa','tga','tag'];
}

sub ok_seq {
    my($pieces) = @_;
    my($i);

#   print STDERR &Dumper(['ok_seq',$pieces]);
    if (@$pieces < 1) { return 0 }
    if ($pieces->[0]->[2] > 50) { return 0 }
    my $strand = ($pieces->[0]->[4] < $pieces->[0]->[5]) ? "+" : "-";
    for ($i=0; ($i < (@$pieces-1)) && &ok_seq1($strand,$pieces->[$i],$pieces->[$i+1]);$i++) {}
    return $i == (@$pieces - 1);
}

sub ok_seq1 {
    my($strand,$piece1,$piece2) = @_;

    my(undef,undef,$p1,undef,$b1,$e1) = @$piece1;
    my(undef,undef,$p2,undef,$b2,$e2) = @$piece2;
    if ($p2 < $p1)       { return 0 }
    my $diffP = $p2 - $p1;
    my $diffD = abs($b2 - $b1);
    my $off   = abs((3 * $diffP) - $diffD);
#   print STDERR "strand=$strand b1=$b1 e1=$e1 b2=$b2 e2=$e2 p1=$p1 p2=$p2 off=$off ",
#                 abs($e1-$b1)," ",abs($e2-$b2)," diffP=$diffP diffD=$diffD\n";
    if ($off > 150) { return 0 }
    if ((abs($e1-$b1) < 99) || (abs($e2-$b2) < 99)) { return 0 } # do not patch short fragments
    if ($strand eq '+')
    {
	if ($b2 > $e2)         { return 0 }
	if ($b2 > ($e1 + 250)) { return 0 }
#	print STDERR "ok_seq1\n";
	return 1;
    }
    else
    {
	if ($b2 < $e2)         { return 0 }
	if ($b2 < ($e1 - 250)) { return 0 }
#	print STDERR "ok_seq1\n";
	return 1;
    }
}

### This routine attemts to construct the appropriate location, even in the presence
### of frameshifts.  $pieces describes the regions of similarity that got patched together.
### $pieces_of_untrans give the pieces of DNA that go into the untranslated string.  $frag
### allows you to map everything back to the full contig and the BEG/END region on it.

sub make_loc {
    my($pieces,$frag,$stopsL) = @_;

    my @stop_codons = $stopsL ? @$stopsL : ('taa','tga','tag');
    my $stops = {};
    foreach $_ (@stop_codons) { $stops->{lc $_} = $stops->{uc $_} = 1; }

    my($contig,$beg,$end,$dna) = @$frag;
    my @locs1 = &locs_from_pieces($pieces);
#    print STDERR &Dumper(['pieces',$pieces,\@locs1]);
    my @locs2 = &remove_embedded_stops(\@locs1,$dna,$stops);
#   print STDERR &Dumper(['make_loc',\@locs2]);
    return @locs2;
}

sub locs_from_pieces {
    my($pieces) = @_;

    return ($pieces->[0]->[4] < $pieces->[0]->[5]) ? 
	   &locs_from_piecesP($pieces) :
	   &locs_from_piecesM($pieces);
}

sub locs_from_piecesP {
    my($pieces) = @_;

#    print STDERR &Dumper(['locs_from_piecesP',$pieces]);
    my @locs = ();

    my @coords = map { [$_->[4],$_->[5]] } @$pieces;
    my $i = 0;
#    print STDERR &Dumper(['coords',\@coords]);
    while ($i < @coords)
    {
	if ($i == (@coords - 1))
	{
	    push(@locs,$coords[$i]);
	    $i++;
	}
	else
	{
	    while ($coords[$i+1]->[0] <= $coords[$i]->[1])
	    {
		$coords[$i+1]->[0] += 3;
	    }

	    my $shift = ($coords[$i+1]->[0] - ($coords[$i]->[1]+1)) % 3;

	    if ($shift == 0)
	    {
		$coords[$i+1]->[0] = $coords[$i]->[0];
		$i++;
	    }
	    elsif ($shift == 1)
	    {
		push(@locs,[$coords[$i]->[0],$coords[$i+1]->[0] - 2]);
		$i++;
	    }
	    else  # $shift == 2
	    {
		push(@locs,[$coords[$i]->[0],$coords[$i+1]->[0]]);
		$i++;
	    }
	}
    }
#    print STDERR &Dumper(['exiting locs_from_piecesP',\@locs]);
    return @locs;
}

sub locs_from_piecesM {
    my($pieces) = @_;

#    print STDERR &Dumper(['locs_from_piecesM',$pieces]);
    my @locs = ();

    my @coords = map { [$_->[4],$_->[5]] } @$pieces;
    my $i = 0;
    while ($i < @coords)
    {
	if ($i == (@coords - 1))
	{
	    push(@locs,$coords[$i]);
	    $i++;
	}
	else
	{
	    while ($coords[$i+1]->[0] >= $coords[$i]->[1])
	    {
		$coords[$i+1]->[0] -= 3;
	    }

	    my $shift = (($coords[$i]->[1] - 1) - $coords[$i+1]->[0]) % 3;

	    if ($shift == 0)
	    {
		$coords[$i+1]->[0] = $coords[$i]->[0];
		$i++;
	    }
	    elsif ($shift == 1)
	    {
		push(@locs,[$coords[$i]->[0],$coords[$i+1]->[0] + 2]);
		$i++;
	    }
	    else  # $shift == 2
	    {
		push(@locs,[$coords[$i]->[0],$coords[$i+1]->[0]]);
		$i++;
	    }
	}
    }
#    print STDERR &Dumper(['exiting locs_from_piecesM',\@locs]);
    return @locs;
}

sub remove_embedded_stops_from_pieces {
    my($pieces,$dna,$stopsL) = @_;
    my($i);

    my @stop_codons = $stopsL ? @$stopsL : ('taa','tga','tag');
    my $stops = {};
    foreach $_ (@stop_codons) { $stops->{lc $_} = $stops->{uc $_} = 1; }

    my @cleaned = ();
    for ($i=0; ($i < @$pieces); $i++)
    {
	my($id1,$id2,$pb,$pe,$b,$e) = @{$pieces->[$i]};
	my @cleaned1 = &clean_span([$b,$e],$dna,$stops,($i == (@$pieces - 1))); 
	foreach my $tuple (@cleaned1)
	{
	    my($b1,$e1) = @$tuple;
	    if ($b1 < $e1)
	    {
		my $pb1 = $pb + int(($b1-$b)/3);
		my $pe1 = $pb1 + int((($e1-2)-$b1)/3);
		push(@cleaned,[$id1,$id2,$pb1,$pe1,$b1,$e1]);
	    }
	    else
	    {
		my $pb1 = $pb + int(($b-$b1)/3);
		my $pe1 = $pb1 + int(($b1-($e1+2))/3);
		push(@cleaned,[$id1,$id2,$pb1,$pe1,$b1,$e1]);
	    }
	}
    }
#   print STDERR &Dumper(['key-pieces',$pieces,\@cleaned]);
    return @cleaned;
}

sub remove_embedded_stops {
    my($locs,$dna,$stops) = @_;
    my($i);

    my @cleaned = ();
    for ($i=0; ($i < @$locs); $i++)
    {
	my @cleaned1 = &clean_span($locs->[$i],$dna,$stops,($i == (@$locs - 1))); 
	push(@cleaned,@cleaned1);
    }
#   print STDERR &Dumper(['key',$locs,\@cleaned]);
    for ($i=1; ($i < @cleaned) && (abs($cleaned[$i]->[1] - $cleaned[$i]->[0]) > 90); $i++) {}
#   print STDERR &Dumper(['key',$locs,\@cleaned]);
    return @cleaned;
}

##

sub clean_span {
    my($loc,$dna,$stops,$last_piece) = @_;

    my($b,$e) = @$loc;
    my $ln = length($dna);
    if ($e > $ln) { $e = $ln } ## It can run just past the end.
    if ($b > $ln) { $b = $ln } ## 

    if (($b < 1) || ($e < 1) || ($b > $ln) || ($e > $ln)) 
    { 
	print STDERR &Dumper(length($dna),$loc,$dna); confess("invalid location"); 
    }
    return ($b < $e) ? &clean_spanP($b,$e,$dna,$stops,$last_piece) :
	               &clean_spanM($b,$e,$dna,$stops,$last_piece);
}

sub clean_spanP {
    my($b,$e,$dna,$stops,$last_piece) = @_;

    my @span = ();
    my $i = $b;
    my $t = $last_piece ? $e-3 : $e;
    while ($i < $t)
    {
	my $codon = substr($dna,$i-1,3);
	if ($stops->{$codon})
	{
	    if ($b == $i)   # if first codon, just skip it
	    {
		$b += 3;
	    }
	    else
	    {
		push(@span,[$b,$i-1]);
		$b = $i + 3;
	    }
	}
	$i += 3;
    }
    if ($b < $e)
    {
	push(@span,[$b,$e]);
    }
    return @span;
}

sub clean_spanM {
    my($b,$e,$dna,$stops,$last_piece) = @_;

    if (($b > length($dna)) || ($e < 1)) { print STDERR &Dumper(length($dna),$b,$e); die "bad bounds $b $e"; }
    my @span = ();
    my $i = $b;
    my $t = $last_piece ? $e+3 : $e;
    while ($i > $t)
    {
	my $codon = &SeedUtils::reverse_comp(substr($dna,$i-3,3));
	if ($stops->{$codon})
	{
	    if ($b == $i)
	    {
		$b -= 3;
	    }
	    else
	    {
		push(@span,[$b,$i+1]);
		$b = $i - 3;
	    }
	}
	$i -= 3;
    }
    if ($b > $e)
    {
	push(@span,[$b,$e]);
    }
    return @span;
}

sub shift_coords {
    my($locs,$beg,$end) = @_;
    my $loc;

    my $dir = ($beg < $end) ? 1 : -1;
    my @shifted = ();
    foreach $loc (@$locs)
    {
	my($b,$e) = @$loc;
	push(@shifted,[$beg + ($dir * ($b-1)), $beg + ($dir * ($e-1))]);
    }
    return @shifted;
}

sub extend_to_start_stop {
    my($sorted,$frag,$params) = @_;

    my $opt = {};
    $opt->{is_init} = $params->{is_init} ? $params->{is_init} : ['ATG','GTG'];
    $opt->{is_alt}  = $params->{is_alt}  ? $params->{is_alt}  : ['TTG'];

    if ((! $params->{code}) || ($params->{code} == 4))
    {
	$opt->{'is_term'} = [ qw( TAA TAG ) ];
    }
    else
    {
	$opt->{'is_term'} = $params->{is_term} ? $params->{is_term} : [ qw( TAA TAG TGA ) ];
    }

    my($contig,$beg,undef,$dna) = @$frag;
    my($start,$rcS) = &find_special_proteins::find_orf_start(\$dna,$sorted->[0]->[4],$sorted->[0]->[5],$opt);

    my $pieceL = $sorted->[@$sorted - 1];
    my($end,$rcE) = &find_special_proteins::find_orf_end(\$dna,$pieceL->[4],$pieceL->[5],$opt);

    if (defined($start) && defined($end) && (! $rcS) && (! $rcE))
    {
	$sorted->[0]->[4] = $start;
	$pieceL->[5] = $end;
	return 1;
    }
    return 0;
}

sub start {
    my($codon) = @_;

    return ($codon =~ /^(atg|gtg|ttg)$/i);
}

sub startC {
    my($codon) = @_;

    return ($codon =~ /^(cat|cac|caa)$/i);
}

sub stop {
    my($codon) = @_;
    return ($codon =~ /^(taa|tag|tga)$/i);
}

sub stopC {
    my($codon) = @_;
    return ($codon =~ /^(tta|cta|tca)$/i);
}

sub make_translation {
    my($locs,$frag) = @_;

    my $i;
    for ($i=0; ($i < (@$locs - 1)); $i++)
    {
	my $db1 = $locs->[$i]->[0];
	my $de1 = $locs->[$i]->[1];

	my $db2 = $locs->[$i+1]->[0];
	my $de2 = $locs->[$i+1]->[1];

	if ($db1 < $de1)
	{
	    if ($de1 >= $db2)
	    {
		my $de1_new = $de1 - 3;
		while ($de1_new >= $db2) { $de1_new -= 3 }
		my $db2_new = $db2 + 3;
		while ($db2_new <= $de1) { $db2_new += 3 }
		$locs->[$i]->[1]   = $de1_new;
		$locs->[$i+1]->[0] = $db2_new;
	    }
	}
	else
	{
	    if ($de1 <= $db2)
	    {
		my $de1_new = $de1 + 3;
		while ($de1_new <= $db2) { $de1_new += 3 }
		my $db2_new = $db2 - 3;
		while ($db2_new >= $de1) { $db2_new -= 3 }
		$locs->[$i]->[1]   = $de1_new;
		$locs->[$i+1]->[0] = $db2_new;
	    }
	}
    }
    my @pieces_of_trans = ();
    my @pieces_of_untrans = ();
    my $dna = $frag->[3];
#    print STDERR &Dumper(['sorted best hit',$locs,$frag]);
#    Trace &Dumper(['sorted best hit',$locs,$dna]) if T(3);

    for ($i=0; ($i < (@$locs - 1)); $i++)
    {
	&add_trans(\@pieces_of_trans,\@pieces_of_untrans,$locs->[$i],$dna,($i == 0));
	&add_gap(\@pieces_of_trans,\@pieces_of_untrans,$locs->[$i]->[1],$locs->[$i+1]->[0],$dna);
    }
    &add_trans(\@pieces_of_trans,\@pieces_of_untrans,$locs->[$i],$dna,($i == 0));
#   print STDERR &Dumper(['pieces',\@pieces_of_trans,\@pieces_of_untrans]);

    my $tran    = join("",@pieces_of_trans);
    my $untran  = join("",@pieces_of_untrans);
    while ($tran =~ /\*[^\n]/)    ### This nonsense is needed to keep *s at the end of a sequence
    {
	$tran =~ s/\*/X/;
    }
    $tran =~ s/\*$//;
    return (\@pieces_of_untrans,$untran,$tran);
}

sub add_gap {
    my($pieces_of_trans,$pieces_of_untrans,$end_of_last,$beg_of_next,$dna) = @_;
    my $gap_dna;
    if ($end_of_last < $beg_of_next)
    {
	$gap_dna = substr($dna,$end_of_last,($beg_of_next - $end_of_last) - 1);
    }
    else
    {
	$gap_dna = &SeedUtils::reverse_comp(substr($dna,$beg_of_next,($end_of_last - $beg_of_next) - 1));
    }
    my $gap = abs($beg_of_next - $end_of_last) - 1;
    push(@$pieces_of_trans,"x" x int(($gap+1) / 3));
    push(@$pieces_of_untrans,$gap_dna);
}
    

sub add_trans {
    my($pieces_of_trans,$pieces_of_untrans,$piece,$dna,$fix_start) = @_;

#   print STDERR &Dumper(['piece in add_trans',$piece,$dna]);

    Trace &Dumper(['piece in add_trans',$piece,$dna]) if T(3);
    my $db = $piece->[0];
    my $de = $piece->[1];

    my $dna_to_tran;
    if ($db < $de)
    {
	$dna_to_tran = substr($dna,$db-1,($de+1-$db));
	if ($fix_start && ($dna_to_tran =~ /[gt]tg/i))
	{
	    substr($dna_to_tran,0,1) = 'A';
	}
    }
    else
    {
	$dna_to_tran = &SeedUtils::reverse_comp(substr($dna,$de-1,($db+1-$de)));
	if ($fix_start && ($dna_to_tran =~ /[gt]tg/i))
	{
	    substr($dna_to_tran,0,1) = 'A';
	}
    }
    push(@$pieces_of_trans,&SeedUtils::translate($dna_to_tran));
    push(@$pieces_of_untrans,$dna_to_tran);
    Trace &Dumper(["trans: ",$dna_to_tran,$pieces_of_trans->[@$pieces_of_trans - 1]]) if T(3);
}

sub remove_embedded {
    my($pieces) = @_;

    my @clean = ();
    my @pieces = sort { $a->[2] <=> $b->[2] } @$pieces;
    foreach my $piece (@pieces)
    {
	if ((@clean == 0) || ($clean[$#clean]->[3] < $piece->[3]))
	{
	    push(@clean,$piece);
	}
    }
#   print STDERR &Dumper(['pieces',\@pieces,'clean',\@clean]);
    return @clean;
}

sub close_to_picked {
    my($pieces,$piece) = @_;

    my $i;
    for ($i=0; ($i < @$pieces) && (! &ok($piece,$pieces->[$i])); $i++) {}
    return ($i < @$pieces);
}

sub ok {
    my($piece1,$piece2) = @_;

    my $strand = ($piece1->[4] < $piece1->[5]) ? '+' : '-';
    return &ok_seq1($strand, $piece1,$piece2) || &ok_seq1($strand,$piece2,$piece1);
}

#    my $b1P = $piece1->[2];
#    my $e1P = $piece1->[3];
#    my $b1D = $piece1->[4];
#    my $e1D = $piece1->[5];
#
#    my $b2P = $piece2->[2];
#    my $e2P = $piece2->[3];
#    my $b2D = $piece2->[4];
#    my $e2D = $piece2->[5];
#
#    if (($b1D < $e1D) && ($b2D < $e2D))
#    {
#	if ($b1D < $b2D)
#	{
#	    return (($b2P - $e1P) < 5);
#	}
#	else
#	{
#	    return (($b1P - $e2P) < 5);
#	}
#    }
#    elsif (($b1D > $e1D) && ($b2D > $e2D))
#    {
#	if ($b1D < $b2D)
#	{
#	    return (($e2D - $b1D) < 5);
#	}
#	else
#	{
#	    return (($e1D - $b2D) < 5);
#	}
#    }
#    return 0;
#}

sub cluster_blast {
    my($blast_out) = @_;

    my @sets = ();
    my $i = 0;
    while ($i < @$blast_out)
    {
	my $set = [$blast_out->[$i]];
	$i++;
	while (($i < @$blast_out) && ($blast_out->[$i]->[0] eq $set->[0]->[0]) && 
	       ($blast_out->[$i]->[1] eq $set->[0]->[1]) &&
	       (abs((($blast_out->[$i]->[4] + $blast_out->[$i]->[5]) / 2) - (($set->[0]->[4] + $set->[0]->[5]) / 2)) < 8000))
	{
	    push(@$set,$blast_out->[$i]);
	    $i++;
	}
	push(@sets,$set);
    }
    return &condense(\@sets);
}

sub condense {
    my($sets) = @_;
    my($i);

    my @keep = ();
    foreach my $set (@$sets)
    {
	for ($i=0; ($i < @keep) && (! &same_region($set,$keep[$i])); $i++) {}
	if ($i == @keep)
	{
	    push(@keep,$set);
	}
    }
    return @keep;
}

sub same_region {
    my($x,$y) = @_;

    my $min1 = &min_hit($x);
    my $max1 = &max_hit($x);
    my $min2 = &min_hit($y);
    my $max2 = &max_hit($y);
    return &SeedUtils::between($min1,$min2,$max1) || &SeedUtils::between($min2,$min1,$max2);
}

sub min_hit {
    my($x) = @_;

    my $min = 100000000;
    foreach my $x1 (@$x)
    {
	$min = &SeedUtils::min($min,$x1->[4],$x1->[5]);
    }
    return $min;
}

sub max_hit {
    my($x) = @_;

    my $max = 0;
    foreach my $x1 (@$x)
    {
	$max = &SeedUtils::max($max,$x1->[4],$x1->[5]);
    }
    return $max;
}

sub write_nap_matrix
{
    my($file) = @_;
    my $fh;
    open($fh, ">", $file) or die "Cannot write $file: $!";
    print $fh <<END;
   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  5 -2 -1 -2 -1 -1 -1  0 -2 -1 -2 -1 -1 -3 -1  1  0 -3 -2  0 -2 -1 -1 -5 
R -2  7 -1 -2 -4  1  0 -3  0 -4 -3  3 -2 -3 -3 -1 -1 -3 -1 -3 -1  0 -1 -5 
N -1 -1  7  2 -2  0  0  0  1 -3 -4  0 -2 -4 -2  1  0 -4 -2 -3  4  0 -1 -5 
D -2 -2  2  8 -4  0  2 -1 -1 -4 -4 -1 -4 -5 -1  0 -1 -5 -3 -4  5  1 -1 -5 
C -1 -4 -2 -4 13 -3 -3 -3 -3 -2 -2 -3 -2 -2 -4 -1 -1 -5 -3 -1 -3 -3 -2 -5 
Q -1  1  0  0 -3  7  2 -2  1 -3 -2  2  0 -4 -1  0 -1 -1 -1 -3  0  4 -1 -5 
E -1  0  0  2 -3  2  6 -3  0 -4 -3  1 -2 -3 -1 -1 -1 -3 -2 -3  1  5 -1 -5 
G  0 -3  0 -1 -3 -2 -3  8 -2 -4 -4 -2 -3 -4 -2  0 -2 -3 -3 -4 -1 -2 -2 -5 
H -2  0  1 -1 -3  1  0 -2 10 -4 -3  0 -1 -1 -2 -1 -2 -3  2 -4  0  0 -1 -5 
I -1 -4 -3 -4 -2 -3 -4 -4 -4  5  2 -3  2  0 -3 -3 -1 -3 -1  4 -4 -3 -1 -5 
L -2 -3 -4 -4 -2 -2 -3 -4 -3  2  5 -3  3  1 -4 -3 -1 -2 -1  1 -4 -3 -1 -5 
K -1  3  0 -1 -3  2  1 -2  0 -3 -3  6 -2 -4 -1  0 -1 -3 -2 -3  0  1 -1 -5 
M -1 -2 -2 -4 -2  0 -2 -3 -1  2  3 -2  7  0 -3 -2 -1 -1  0  1 -3 -1 -1 -5 
F -3 -3 -4 -5 -2 -4 -3 -4 -1  0  1 -4  0  8 -4 -3 -2  1  4 -1 -4 -4 -2 -5 
P -1 -3 -2 -1 -4 -1 -1 -2 -2 -3 -4 -1 -3 -4 10 -1 -1 -4 -3 -3 -2 -1 -2 -5 
S  1 -1  1  0 -1  0 -1  0 -1 -3 -3  0 -2 -3 -1  5  2 -4 -2 -2  0  0 -1 -5 
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  2  5 -3 -2  0  0 -1  0 -5 
W -3 -3 -4 -5 -5 -1 -3 -3 -3 -3 -2 -3 -1  1 -4 -4 -3 15  2 -3 -5 -2 -3 -5 
Y -2 -1 -2 -3 -3 -1 -2 -3  2 -1 -1 -2  0  4 -3 -2 -2  2  8 -1 -3 -2 -1 -5 
V  0 -3 -3 -4 -1 -3 -3 -4 -4  4  1 -3  1 -1 -3 -2  0 -3 -1  5 -4 -3 -1 -5 
B -2 -1  4  5 -3  0  1 -1  0 -4 -4  0 -3 -4 -2  0  0 -5 -3 -4  5  2 -1 -5 
Z -1  0  0  1 -3  4  5 -2  0 -3 -3  1 -1 -4 -1  0 -1 -2 -2 -3  2  5 -1 -5 
X -1 -1 -1 -1 -2 -1 -1 -2 -1 -1 -1 -1 -1 -2 -2 -1  0 -3 -1 -1 -1 -1 -1 -5 
* -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5 -5  1 
END
    close($fh);
}

1;
