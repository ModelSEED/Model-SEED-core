# -*- perl -*-

#
# This is a SAS Component
#

#########################################################################
# Copyright (c) 2003-2008 University of Chicago and Fellowship
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
#########################################################################

package SeedV;

use FileHandle;
use Carp;
use strict;
use Data::Dumper;
use DB_File;
use File::Basename;
use SeedUtils;
use CorrTableEntry;
use SAPserver;

my $pseed_url = 'http://servers.nmpdr.org/pseed/sapling/server.cgi';

sub new {
    my ($class, $org_dir ) = @_;

    $org_dir || confess("$org_dir must be a valid SEED directory");
    my $self         = {};
    $self->{_orgdir} = $org_dir;
    ($org_dir =~ /(\d+\.\d+)$/) || confess("$org_dir must be a path ending in the genome ID");
    $self->{_genome} = $1;

    return bless $self, $class;
}

sub genome_id
{
    return $_[0]->{_genome};
}

# return the path of the organism directory
sub organism_directory {
  return $_[0]->{_orgdir};
}

sub get_basic_statistics
{
    my($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    #
    # Check cache.
    #

    my $cache = "$newGdir/cache.basic_statistics";
    my $fh = new FileHandle($cache);
    if ($fh)
    {
	my $stats = {};
	while (<$fh>)
	{
	    chomp;
	    my($k, $v) = split(/\t/);
	    $stats->{$k} = $v;
	}
	close($fh);
	return $stats;
    }


    my $subsystem_data = $self->get_genome_subsystem_data();

    my %sscount = map { $_->[0] => 1 } @$subsystem_data;
    my $nss=scalar(keys(%sscount));

    my $statistics = {
	num_subsystems => $nss,
	num_contigs    => scalar($self->all_contigs()),
	num_basepairs  => $self->genome_szdna(),
	genome_name    => $self->genus_species(),
	genome_domain  => $self->genome_domain(),
	genome_pegs    => $self->genome_pegs(),
	genome_rnas    => $self->genome_rnas(),
	};

    $fh = new FileHandle(">$cache");
    if ($fh)
    {
	while (my($k, $v) = each %$statistics)
	{
	    print $fh join("\t", $k, $v), "\n";
	}
	close($fh);
    }
    return $statistics;
}


sub get_peg_statistics {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my $cache = "$newGdir/cache.peg_statistics";
    my $fh = new FileHandle($cache);
    if ($fh)
    {
	my $stats = {};
	while (<$fh>)
	{
	    chomp;
	    my($k, $v) = split(/\t/);
	    $stats->{$k} = $v;
	}
	close($fh);
	return $stats;
    }


    my $subsystem_data = $self->get_genome_subsystem_data();
    my $assignment_data = $self->get_genome_assignment_data();

    my $hypo_sub = 0;
    my $hypo_nosub = 0;
    my $nothypo_sub = 0;
    my $nothypo_nosub = 0;
    my %in = map { $_->[2] => 1 } @$subsystem_data;
    my $in = keys(%in);

    my %sscount = map { $_->[0] => 1 } @$subsystem_data;

    foreach $_ (@$assignment_data)
    {
	my($peg,$func) = @$_;

	my $is_hypo = &SeedUtils::hypo($func);
	    
	if    ($is_hypo && $in{$peg})           { $hypo_sub++ }
	elsif ($is_hypo && ! $in{$peg})         { $hypo_nosub++ }
	elsif ((! $is_hypo) && (! $in{$peg}))   { $nothypo_nosub++ }
	elsif ((! $is_hypo) && $in{$peg})       { $nothypo_sub++ }
    }
    my $tot = $hypo_sub + $nothypo_sub + $hypo_nosub + $nothypo_nosub;

    my ($fracHS, $fracNHS, $fracHNS, $fracNHNS);

    if ($tot == 0) {
	$fracHS = sprintf "%.2f", 0.0;
	$fracNHS = sprintf "%.2f", 0.0;
	$fracHNS = sprintf "%.2f", 0.0;
	$fracNHNS = sprintf "%.2f", 0.0;
    } else {
	$fracHS = sprintf "%.2f", $hypo_sub / $tot * 100;
	$fracNHS = sprintf "%.2f", $nothypo_sub / $tot * 100;
	$fracHNS = sprintf "%.2f", $hypo_nosub / $tot * 100;
	$fracNHNS = sprintf "%.2f", $nothypo_nosub / $tot * 100;
    }

    my $statistics = {
	hypothetical_in_subsystem => $hypo_sub,
	hypothetical_not_in_subsystem => $hypo_nosub,
	non_hypothetical_in_subsystem => $nothypo_sub,
	non_hypothetical_not_in_subsystem => $nothypo_nosub,
	hypothetical_in_subsystem_percent => $fracHS,
	hypothetical_not_in_subsystem_percent => $fracHNS,
	non_hypothetical_in_subsystem_percent => $fracNHS,
	non_hypothetical_not_in_subsystem_percent => $fracNHNS
	};

    $fh = new FileHandle(">$cache");
    if ($fh)
    {
	while (my($k, $v) = each %$statistics)
	{
	    print $fh join("\t", $k, $v), "\n";
	}
	close($fh);
    }

    return $statistics;
}
sub get_variant_and_bindings
{
    my($self, $ssa) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    $self->load_ss_data();

    my $bindings = $self->{_ss_bindings}->{$ssa};
    my $variant = $self->{_ss_variants}->{$ssa};

    unless ($bindings) {
	$variant = '*-1';
	$bindings = {};	
    }

    return ($variant, $bindings);
}

sub active_subsystems
{
    my($self, $all) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    $self->load_ss_data();

    my $slist = {};

    if ($self->{_ss_variants})
    {
	%{$slist} = %{$self->{_ss_variants}};
    }

    if (not $all)
    {
	for my $ss (keys %$slist)
	{
	    my $var = $slist->{$ss};
	    delete $slist->{$ss} if $var eq 0 or $var eq -1;
	}
    }
    return $slist;
}

sub peg_to_subsystems
{
    my($self, $peg) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    $self->load_ss_data();

    my $variant = $self->{_ss_variants};
    my %sub = map { $_ => 1 }
              grep { $variant->{$_} !~ /^(-1)|0$/ }
              map { $_->[0] }
              $self->peg_to_roles_in_subsystems($peg);
    return sort keys(%sub);
}

sub peg_to_roles_in_subsystems
{
    my($self,$peg) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    $self->load_ss_data();

    my $ret  = $self->{_ss_peg_index}->{$peg};

    return $ret ? @$ret : ();
}

sub subsystems_for_peg
{
    my($self,$peg) = @_;
    return $self->peg_to_roles_in_subsystems($peg);
}

sub subsystems_for_peg_complete {
    my ($self, $peg) = @_;
    
    my $newG = $self->{_genome};

    $self->load_ss_data();

    my $ret = $self->{_ss_peg_index}->{$peg};
    if ($ret) {
	return map { [ $_->[0], $_->[1], $self->{_ss_variants}->{$_->[0] }, $peg ] } @$ret;
    } else {
	return ();
    }
}

sub genus_species {
    my($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (open(GENOME,"<$newGdir/GENOME"))
    {
	my $x = <GENOME>;
	close(GENOME);
	chop $x;
	return $x;
    }
    else
    {
	return "";
    }
}

sub get_genome_assignment_data {
    my($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my @fnfiles = <$newGdir/proposed*functions>;
    if (@fnfiles == 0)
    {
	@fnfiles = <$newGdir/assigned*functions>;
    }

    if (@fnfiles == 0)
    {
	return [];
    }
    my %assign;
    for my $file (@fnfiles)
    {
	my $fh;
	if (!open($fh, "<", $file))
	{
	    warn "Cannot open $file: $!";
	    next;
	}
		    
	while (<$fh>)
	{
	    if ( $_ =~ /^(fig\|\d+\.\d+\.peg\.\d+)\t(\S.*\S)/)
	    {
		my($fid,$func) = ($1,$2);
		$assign{$fid} = $func;
	    }
	}
	close($fh);
    }
    return [map { [$_,$assign{$_}] } sort { &SeedUtils::by_fig_id($a,$b) } keys(%assign)];
}

sub get_genome_subsystem_data {
    my($self,$genome) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my $fh;
    open($fh, "<", "$newGdir/Subsystems/subsystems");
    my %operational = map { (($_ =~ /^(\S.*\S)\t(\S+)/) && (($2 ne '-1') && ($2 ne '0'))) ? ($1 => 1) : () } <$fh>;
    close($fh);

    open($fh, "<", "$newGdir/Subsystems/bindings");
    my $rc =  [grep { ! $self->is_deleted_fid($_->[2]) }
	        map { (($_ =~ /^(\S[^\t]+\S)\t(\S[^\t]*\S)\t(\S+)/) && $operational{$1} ) ? [$1,$2,$3] : () }
		<$fh>];
    close($fh);
    return $rc;
}

sub get_genome_subsystem_count
{
    my($self,$genome) = @_;
    
    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};
    

	my $count = 0;
	my ($entry, $vc);
	open(SUBSYSTEMS, "<$newGdir/Subsystems/subsystems");
	while (defined($entry = <SUBSYSTEMS>))
	{
	    chomp $entry;
	    (undef, $vc) = split /\t/, $entry;
	    if ($vc != -1) { ++$count; }
	}
	close(SUBSYSTEMS);
	return $count;
}

sub orgname_of_orgid {
    my($self,$genome) = @_;

    return $self->genus_species();
}

sub genus_species_domain {
    my($self,$genome) = @_;

    return [$self->genus_species(),$self->genome_domain()];
}

sub protein_subsystem_to_roles {
    my ($self,$peg,$subsystem) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    open(my $fh, "<", "$newGdir/Subsystems/bindings");

    my @roles = map { (($_ =~ /^([^\t]+)\t([^\t]+)\t(\S+)$/) && ($1 eq $subsystem) && ($3 eq $peg)) ?
			  $2 : () } <$fh>;
    my %roles = map { $_ => 1 } @roles;
    return [sort keys(%roles)];
}

sub contig_lengths {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my $contig_lengths = $self->{_contig_len_index};

    # $self->load_contigs_index();
    if (!tied(%$contig_lengths))
    {
	$self->load_contig_len_cache();
	return $self->{_contig_len_cache};
    }
    return $contig_lengths;
}

sub load_contig_len_cache
{
    my($self) = @_;

    return if ref $self->{_contig_len_cache};
		  
    my $newGdir = $self->{_orgdir};

    my $contig_lengths = {};
    if (open(CONTIGS,"<$newGdir/contigs"))
    {
	local $/ = "\n>";
	while (defined(my $x = <CONTIGS>))
	{
	    chomp $x;
	    if ($x =~ />?(\S+)[^\n]*\n(.*)/s)
	    {
		my $id = $1;
		my $seq = $2;
		$seq =~ s/\s//gs;
		$contig_lengths->{$id} = length($seq);
	    }
	}
	close(CONTIGS);
    }
    $self->{_contig_len_cache} = $contig_lengths;
}

sub contig_ln {
    my ($self, $contig) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    $self->load_contig_len_cache();
    return $self->{_contig_len_cache}->{$contig};
}

sub contig_entrypoints
{
    my($self) = @_;
    $self->load_tbl();
    return $self->{_contig_entrypoints};
}

sub contigs_of
{
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	my @out;
	$self->load_contigs_index();

	my $contigs = $self->{_contigs_index};
	if (tied(%$contigs))
	{
	    return keys %$contigs;
	}

	$self->load_contig_len_cache();

	return keys %{$self->{_contig_len_cache}};
}

=head3 dna_seq

usage: $seq = dna_seq(@locations)

Returns the concatenated subsequences described by the list of locations.  Each location
must be of the form

    Contig_Beg_End

where Contig must be the ID of a contig for genome $genome.  If Beg > End the location
describes a stretch of the complementary strand.

=cut
#: Return Type $;
sub dna_seq {
    my($self,@locations) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my $contigs = $self->{_contigs_index};
    if (!tied %$contigs)
    {
	$self->load_contig_seq();
	$contigs = $self->{_contigs_seq_cache};
    }

    my(@pieces,$loc,$contig,$beg,$end,$ln,$rdbH);

    @locations = map { split(/,/,$_) } @locations;
    @pieces = ();
    foreach $loc (@locations)
    {
        if ($loc =~ /^(\S+)_(\d+)_(\d+)$/)
        {
            ($contig,$beg,$end) = ($1,$2,$3);
	    my $seq = $contigs->{$contig};

            $ln = length($seq);

            if (! $ln) {
                print STDERR "$contig: could not get length\n";
                return "";
            }

            if (&SeedUtils::between(1,$beg,$ln) && &SeedUtils::between(1,$end,$ln))
            {
                if ($beg < $end)
                {
                    push(@pieces, substr($seq, $beg - 1, ($end - $beg) + 1));
                }
                else
                {
                    push(@pieces, &SeedUtils::reverse_comp(substr($seq, $end - 1, ($beg - $end) + 1)));
                }
            }
        }
    }
    return lc(join("",@pieces));
}

sub load_contig_seq
{
    my($self) = @_;

    return if ref($self->{_contigs_seq_cache});

    my $newGdir = $self->{_orgdir};

    my $contigs = {};

    if (open(CONTIGS,"<$newGdir/contigs"))
    {
	local $/ = "\n>";
	while (defined(my $x = <CONTIGS>))
	{
	    chomp $x;
	    if ($x =~ />?(\S+)[^\n]*\n(.*)/s)
	    {
		my $id = $1;
		my $seq = $2;
		$seq =~ s/\s//gs;
		$contigs->{$id} = $seq;
	    }
	}
	close(CONTIGS);
    }
    $self->{_contigs_seq_cache} = $contigs;
}

sub genome_szdna {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	my $contig_lens = $self->contig_lengths();
	my $tot = 0;
	while ( my($contig,$len) = each %$contig_lens)
	{
	    $tot += $len;
	}
	return $tot;
}

sub genome_pegs {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my @tmp = $self->all_features("peg");
    my $n = @tmp;
    return $n;
}

sub genome_rnas {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	my @tmp = $self->all_features("rna");
	my $n = @tmp;
	return $n;
}

sub genome_domain {
    my ($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	my $tax = $self->taxonomy_of();
	return ($tax =~ /^([^ \t;]+)/) ? $1 : "unknown";
}

sub genes_in_region {
    my($self,$contig,$beg,$end) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	$self->load_feature_indexes();
	#
	# Use the recno index if exists.
	#

	my $maxV = 0;
	my $minV = 1000000000;
	my $genes = [];

	my $recnos = $self->{_feat_recno};

	if (ref($recnos))
	{
	    while (my($ftype, $list) = each (%$recnos))
	    {
		#
		# Look up start/end of this contig in the btree index.
		#
		
		my $inf = $self->{_feat_btree}->{$ftype}->{$contig};
		my($istart, $iend);
		if ($inf)
		{
		    ($istart, $iend) = split(/$;/, $inf);
		}
		else
		{
		    $istart = 0;
		    $iend = $#$list;
		}

		for (my $idx = $istart; $idx <= $iend; $idx++)
		{
		    my($fid, $fcontig, $fbeg, $fend, $fstrand) = split(/$;/, $list->[$idx]);
		    if ($contig eq $fcontig and &overlaps($beg, $end, $fbeg, $fend))
		    {
			$minV = &SeedUtils::min($minV,$fbeg,$fend);
			$maxV = &SeedUtils::max($maxV,$fbeg,$fend);
			push(@$genes,$fid);
		    }
		}
	    }
	}
	else
	{
	    &load_tbl($self);
	    my $tblH = $self->{_tbl};
	    while ( my($fid,$tuple) = each %$tblH)
	    {
		next if $self->is_deleted_fid($fid);
		if (($tuple->[0]->[0] =~ /^(\S+)_(\d+)_\d+$/) && ($1 eq $contig))
		{
		    my $beg1 = $2;
		    my $last = @{$tuple->[0]} - 1;
		    if (($tuple->[0]->[$last] =~ /^(\S+)_\d+_(\d+)$/) && ($1 eq $contig))
		    {
			my $end1 = $2;
			if (&overlaps($beg,$end,$beg1,$end1))
			{
			    $minV = &SeedUtils::min($minV,$beg1,$end1);
			    $maxV = &SeedUtils::max($maxV,$beg1,$end1);
			push(@$genes,$fid);
			}
		    }
		}
	    }
	}
	return ($genes,$minV,$maxV);
}

sub overlaps {
    my($b1,$e1,$b2,$e2) = @_;

    if ($b1 > $e1) { ($b1,$e1) = ($e1,$b1) }
    if ($b2 > $e2) { ($b2,$e2) = ($e2,$b2) }
    return &SeedUtils::between($b1,$b2,$e1) || &SeedUtils::between($b2,$b1,$e2);
}

sub all_contigs {
    my($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	$self->load_feature_indexes();

	my %contigs;
	my $btrees = $self->{_feat_btree};

	if (ref($btrees))
	{
	    while (my($ftype, $btree) = each (%$btrees))
	    {
		map { $contigs{$_} = 1 } grep { !/^fig/ } keys %$btree ;
	    }
	}
	else
	{
	    &load_tbl($self);
	    my $tblH = $self->{_tbl};
	    while ( my($fid,$tuple) = each %$tblH)
	    {
		if ($tuple->[0]->[0] =~ /^(\S+)_\d+_\d+$/)
		{
		    $contigs{$1} = 1;
		}
	    }
	}
	return keys(%contigs);
}

sub all_features {
    my($self,$type) = @_;
    if (not defined($type)) { $type = qq(); }
    
    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};
    
	#warn "Loading feature indices";
	$self->load_feature_indexes();
	
	my %contigs;
	my $btrees = $self->{_feat_btree};
	
	if (ref($btrees)) {
	    warn "B-tree already loaded" if $ENV{FIG_VERBOSE};
	    
	    my $btree = $btrees->{$type};
	    return sort { &SeedUtils::by_fig_id($a, $b) }
	    	grep { /^fig/ } keys %$btree;
	}
	else {
	    warn "Loading contig B-tree" if $ENV{FIG_VERBOSE};
	    
	    &load_tbl($self);
	    my $tblH = $self->{_tbl};

	    return sort { 
		&SeedUtils::by_fig_id($a,$b)
		} grep {
		    #...NOTE: Matches all feature types if $type is the null string
		    ($_ =~ /^fig\|\d+\.\d+\.([^\.]+)/) && ($1 =~ m/$type/)
		    } keys(%$tblH);
	}
}

sub all_features_detailed_fast {
    my($self,$regmin, $regmax, $contig) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

	$self->load_feature_indexes();
	my $feat_details = [];
	my $recnos = $self->{_feat_recno};

	if (ref($recnos))
	{
	    while (my($ftype, $list) = each (%$recnos))
	    {
		#
		# Look up start/end of this contig in the btree index.
		#
		
		my $inf = $self->{_feat_btree}->{$ftype}->{$contig};
		my($istart, $iend);
		if ($inf)
		{
		    ($istart, $iend) = split(/$;/, $inf);
		}
		else
		{
		    $istart = 0;
		    $iend = $#$list;
		}

		for (my $idx = $istart; $idx <= $iend; $idx++)
		{
		    my($fid, $fcontig, $fbeg, $fend, $fstrand) = split(/$;/, $list->[$idx]);
		    next if $self->is_deleted_fid($fid);
		    
		    if (not defined($regmin) or not defined($regmax) or not defined($contig) or
			(($contig eq $fcontig) and
			 ($fbeg < $regmin and $regmin < $fend) or ($fbeg < $regmax and $regmax < $fend) or ($fbeg > $regmin and $fend < $regmax)))
		    {
			my($loc, $index, @aliases) = split(/$;/, $self->{_feat_btree}->{$ftype}->{$fid});

			my $function = $self->function_of($fid);			
			push(@$feat_details,[$fid, $loc, join(",", @aliases), $ftype, $fbeg, $fend, $function,'master','']);
		    }
		}
	    }
	}
	else
	{
	    &load_tbl($self);
	    my $tblH = $self->{_tbl};
	    while ( my($fid,$tuple) = each %$tblH)
	    {
		next if $self->is_deleted_fid($fid);
		if ($fid =~ /^fig\|\d+\.\d+\.(\S+)\.\d+/)
		{
		    my $type = $1;
		    if ($tuple->[0]->[0] =~ /^(\S+)_(\d+)_(\d+)$/)
		    {
			my($ctg, $beg, $end) = ($1, $2, $3);
			next if (defined($contig) and $contig ne $ctg);
			
			my($min,$max);
			if ($beg < $end)
			{
			    $min = $beg;
			    $max = $end;
			}
			else
			{
			    $min = $end;
			    $max = $beg;
			}
			
			if (not defined($regmin) or not defined($regmax) or
			    ($min < $regmin and $regmin < $max) or ($min < $regmax and $regmax < $max) or ($min > $regmin and $max < $regmax))
			{
			    my $function = $self->function_of($fid);
			    push(@$feat_details,[$fid,$tuple->[0]->[0],join(",",@{$tuple->[1]}),$type,$min,$max,$function,'master','']);
			}
		    }
		}
	    }
	}
	return $feat_details;
}

sub feature_location {
    my($self,$fid) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($fid =~ /^fig\|(\d+\.\d+)\.([^.]+)/) && ($1 eq $newG))
    {
	my $ftype = $2;
	
	$self->load_feature_indexes();

	my $btree = exists($self->{_feat_btree}) ? $self->{_feat_btree}->{$ftype} : undef;
	if ($btree)
	{
	    my($loc, $idx, @aliases) = split(/$;/, $btree->{$fid});
	    return wantarray ? split(/,/, $loc) : $loc;
	}
	else
	{
	    &load_tbl($self);
	    if (my $x = $self->{_tbl}->{$fid})
	    {
		if (wantarray)
		{
		    return @{$x->[0]};
		}
		else
		{
		    return join(",",@{$x->[0]});
		}
	    }
	    else
	    {
		return undef;
	    }
	}
    }
    return undef;
}

sub function_of {
    my($self,$fid) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	&load_functions($self);
	
	my $fn = $self->{_functions}->{$fid};
	if (wantarray)
	{
	    return ['master', $fn];
	}
	else
	{
	    return $fn;
	}
    }
    return "";
}

sub assign_function
{
    my($self, $fid, $user, $function, $confidence) = @_;

    $confidence = $confidence ? $confidence : "";

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 ne $newG))
    {
	warn "assign_function on non-seedv fid\n";
	return 0;
    }

    $function =~ s/\s+/ /sg;  # No multiple spaces
    $function =~ s/^\s+//;    # No space at begining
    $function =~ s/\s+$//;    # No space at end
    $function =~ s/ ; /; /g;  # No space before semicolon
    
    my $file = "$newGdir/proposed_user_functions";
    my $status = 1;
    if ( open( TMP, ">>$file" ) )
    {
        print TMP "$fid\t$function\t$confidence\n";
        close(TMP);
    }
    else
    {
        print STDERR "FAILED ASSIGNMENT: $fid\t$function\t$confidence\n";
        $status = 0;
    }

    # mdj:  force reload of functions to pick up new assignment
    $self->load_functions(1);

    #  We are not getting annotations logged.  So, we will impose it here.
    $self->add_annotation( $fid, $user, "Set master function to\n$function\n" );

    #
    # Mark the genome directory as in need of having bindings recomputed.
    #
#     if (open(S, "<$newGdir/Subsystems/subsystems"))
#     {
# 	while (<S>)
# 	{
# 	    chomp;
# 	    my($sname, $v) = split(/\t/);
# 	    open(SFILE, ">$self->{_orgdir}/Subsystems/${sname}_bindings_need_recomputation");
# 	    close(SFILE);
# 	}
# 	close(S);
#     }
    return $status;
}

sub add_annotation {
    my($self,$feature_id,$user,$annotation, $time_made) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($feature_id =~ /^fig\|(\d+\.\d+)/) && ($1 ne $newG))
    {
	warn "add_annotation on non-seedv fid '$feature_id'\n";
	return 0;
    }

    $time_made = time unless $time_made =~ /^\d+$/;

    if ($self->is_deleted_fid($feature_id)) { return 0 }

#   print STDERR "add: fid=$feature_id user=$user annotation=$annotation\n";

    my $file = "$newGdir/annotations";
    my $ma   = ($annotation =~ /^Set master function to/);
    
    if (open(TMP,">>$file"))
    {
	my $dataLine = "$feature_id\n$time_made\n$user\n$annotation" . ((substr($annotation,-1) eq "\n") ? "" : "\n");
	print TMP $dataLine . "//\n";
	close(TMP);
	
	#
	# Update local cache.
	#
	my $ann = $self->{_ann};
	push(@{$ann->{$feature_id}}, [$feature_id, $time_made, $user, $annotation . "\n"]);
    }
    else
    {
	warn "Cannot write $file: $!";
    }
    return 0;
}


=pod

find_features_by_annotation

Takes a reference to a hash of functions to find and an optional case boolean, and returns a hash with keys are the function and values are a reference to an array of the IDs that have that function.

If the case boolean is set the search is case insensitive. Otherwise case sensitive.

=cut

sub find_features_by_annotation {
	my($self,$anno_hash, $case)=@_;
	$self->load_functions;

	if ($case) {map {$anno_hash->{uc($_)}=1} keys %$anno_hash}
	
	my $res={};
	foreach my $id (keys %{$self->{_functions}})
	{
		my $fn = $self->{_functions}->{$id};
		$case ? $fn = uc($fn) : 1;
		if ($anno_hash->{$fn}) {push @{$res->{$fn}}, $id}
	}
	
	return $res;
}


=pod 

search_features_by_annotation

Takes a string to find and an optional case boolean, and returns a
hash with keys are the function and values are a reference to an array
of the IDs that have that function.

If the case boolean is set the search is case insensitive. Otherwise case sensitive.

Note that this was originally based on the find above, but this uses a
regexp for matching. Will likely be a lot slower which is why I only
search for a single term. There may be an SQL way of doing this, if so
let Rob know how to do it and I'll replace this method.


=cut

sub search_features_by_annotation {
	my($self,$term, $case)=@_;
	$self->load_functions;

	# to make case insensitive convert everything to uppercase
	# alternative is to use two regexps, one for case insens and one for not case insens
	# but the bad thing about that approach is that if you have a case insensitive search
	# you do two regexps for each failed match
	
	$case ? $term = uc($term) : 1;

	my $res={};
	foreach my $id (keys %{$self->{_functions}})
	{
		# we set two variables, one that has case changed for case insensitive searches
		my $fn = my $fnc = $self->{_functions}->{$id};
		$case ? $fn = uc($fn) : 1;
		if ($fn =~ m/$term/) {push @{$res->{$fnc}}, $id}
	}
	
	return $res;
}


sub feature_aliases {
    my($self,$fid) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my @aliases;

    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	&load_tbl($self);
	if (my $x = $self->{_tbl}->{$fid})
	{
	    @aliases = @{$x->[1]};
	}
	else
	{
	    @aliases = ();
	}
    }
    else
    {
	@aliases = ();
    }
    return wantarray() ? @aliases : join(",",@aliases);
}

sub get_corresponding_ids {
    my($self, $id, $with_type_info) = @_;
    
    my $newG    = $self->{_genome};

    if (($id =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG)) {
	my @aliases = $self->feature_aliases($id);
	my @corresponding_ids = ();
	foreach my $alias (@aliases) {
	    if ($alias =~ /^gi\|/) {
		if ($with_type_info) {
		    push(@corresponding_ids, [$alias, 'NCBI']);
		} else {
		    push(@corresponding_ids, $alias);
		}
		last;
	    }
	}
	return @corresponding_ids;
    }
}

sub feature_annotations {
    my($self,$fid,$rawtime) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my @annotations;
    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	&load_ann($self);
	if (my $x = $self->{_ann}->{$fid})
	{
	    @annotations = @{$x};
	}
	else
	{
	    @annotations = ();
	}

	if ($rawtime)
	{
	    return @annotations;
	}
	else
	{
	    return map { my $r = [@$_]; $r->[1] = localtime($r->[1]); $r } @annotations;
	}
    }
    return ();
}

sub get_translation {
    my($self,$peg) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($peg =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	&load_feature_indexes($self);

	my $out = $self->{_feat}->{peg}->{$peg};
	if (defined($out))
	{
	    return $out;
	}

	#
	# If we have a blast-formatted fasta, use fastacmd to
	# do the lookup, and cache the output for later use.
	#

	if ($self->{_feat_fasta}->{peg})
	{
	    my $id = "gnl|$peg";
	    my $cmd = "$FIG_Config::ext_bin/fastacmd -d $self->{_feat_fasta}->{peg} -s '$id'";
	    open(P, "$cmd|") or die "get_translation: cmd failed with $!: $cmd";
	    $_ = <P>;
	    my $out;
	    while (<P>)
	    {
		s/\s+//g;
		$out .= $_;
	    }
	    close(P);
	    $self->{_feat}->{$peg} = $out;
	    return $out;
	}
	else
	{
	    return $self->{_feat}->{$peg};
	}
    }
    else
    {
	return undef;
    }
}

sub translation_length
{
    my($self, $peg) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($peg =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	my $t = $self->get_translation($peg);
	return length($t);
    }
    return undef;
}

sub load_feature_hash {
    my($self,$type) = @_;

    my $newGdir = $self->{_orgdir};
    my $typeH = {};
    if (open(FIDS,"<$newGdir/Features/$type/tbl"))
    {
	while ($_ = <FIDS>)
	{
	    if ($_ =~ /^(\S+)/)
	    {
		my $fid = $1;
		if (! $self->is_deleted_fid($fid))
		{
		    $typeH->{$fid} = 1;
		}
	    }
	}
	close(FIDS);
    }
    return $typeH;
}
    
sub load_feature_indexes
{
    my($self) = @_;

    if ($self->{_feat}) { return };

    my $newGdir = $self->{_orgdir};

    for my $ftype ($self->feature_types())
    {
	my $fdir = "$newGdir/Features/$ftype";
	my $ftype = basename($fdir);

	#
	# If we have a tbl.btree, tie that for our use.
	#
	
	my $tbl_idx = {};
	my $tie = tie %$tbl_idx, 'DB_File', "$fdir/tbl.btree", O_RDONLY, 0666, $DB_BTREE;
	if ($tie)
	{
	    $self->{_feat_tie}->{$ftype} = $tie;
	    $self->{_feat_btree}->{$ftype} = $tbl_idx;
	}

	my $tbl_list = [];
	my $ltie = tie @$tbl_list, 'DB_File', "$fdir/tbl.recno", O_RDONLY, 0666, $DB_RECNO;
	if ($tie)
	{
	    $self->{_feat_ltie}->{$ftype} = $ltie;
	    $self->{_feat_recno}->{$ftype} = $tbl_list;
	}

	#
	# If we have fasta.norm.phr, set _pseq_fasta to the fasta file to use with fastacmd.
	#
	
	my $pseq     = {};

	if (-f "$fdir/fasta.norm.phr")
	{
	    $self->{_feat_fasta}->{$ftype} = "$fdir/fasta.norm";

	}
	else
	{
	    #
	    # Otherwise, we need to load the data.
	    #

	    if (open(FASTA,"<$newGdir/Features/peg/fasta"))
	    {
		local $/ = "\n>";
		my $x;
		while (defined($x = <FASTA>))
		{
		    chomp $x;
		    if ($x =~ />?(\S+)[^\n]*\n(.*)/s)
		    {
			my $peg = $1;
			my $seq = $2;
			$seq =~ s/\s//gs;
			if (! $self->is_deleted_fid($peg))
			{
			    $pseq->{$peg} = $seq;
			}
		    }
		}
		close(FASTA);
	    }
	}
	$self->{_feat}->{$ftype} = $pseq;
    }
}

sub load_pseq {
    my($self) = @_;

    if ($self->{_pseq}) { return };

    my $newGdir = $self->{_orgdir};
    my $fdir = "$newGdir/Features/peg";

    #
    # If we have a tbl.btree, tie that for our use.
    #

    my $tbl_idx = {};
    my $tie = tie %$tbl_idx, 'DB_File', "$fdir/tbl.btree", O_RDONLY, 0666, $DB_BTREE;
    if ($tie)
    {
	$self->{_tbl_tie} = $tie;
	$self->{_tbl_btree} = $tbl_idx;
    }

    #
    # If we have fasta.norm.phr, set _pseq_fasta to the fasta file to use with fastacmd.
    #

    my $pseq     = {};

    if (-f "$fdir/fasta.norm.phr")
    {
	$self->{_pseq_fasta} = "$fdir/fasta.norm";
    }
    else
    {
	#
	# Otherwise, we need to load the data.
	#

	if (open(FASTA,"<$newGdir/Features/peg/fasta"))
	{
	    local $/ = "\n>";
	    my $x;
	    while (defined($x = <FASTA>))
	    {
		chomp $x;
		if ($x =~ />?(\S+)[^\n]*\n(.*)/s)
		{
		    my $peg = $1;
		    my $seq = $2;
		    $seq =~ s/\s//gs;
		    if (! $self->is_deleted_fid($peg))
		    {
			$pseq->{$peg} = $seq;
		    }
		}
	    }
	    close(FASTA);
	}
    }
    $self->{_pseq} = $pseq;
}

sub load_ss_data
{
    my($self, $force) = @_;

    return if defined($self->{_ss_bindings}) && (! $force);

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    open(S, "<$newGdir/Subsystems/bindings") or die "Cannot open $newGdir/Subsystems/bindings: $!";

    my $peg_index;
    my $bindings;

    while (<S>)
    {
	chomp;
	my($sname, $role, $peg) = split(/\t/);
	if (! $self->is_deleted_fid($peg))
	{
	    push(@{$bindings->{$sname}->{$role}}, $peg);
	    push(@{$peg_index->{$peg}}, [$sname, $role]);
	}

    }
    close(S);

    open(S, "<$newGdir/Subsystems/subsystems") or die "Cannot open $newGdir/Subsystems/subsystems: $!";
    my $variant;
    while (<S>)
    {
	chomp;
	my($sname, $v) = split(/\t/);
	$variant->{$sname} = $v;
    }
    close(S);

    $self->{_ss_bindings}     = $bindings;
    $self->{_ss_variants}     = $variant;
    $self->{_ss_peg_index}    = $peg_index;
}

sub load_tbl {
    my($self) = @_;

    if ($self->{_tbl}) { return };

    my $newGdir = $self->{_orgdir};
    my $tbl     = {};

    my $contig_entries = [];
    my $cur_contig;
    
    for my $type ($self->feature_types())
    {
	my $tbl_file = "$newGdir/Features/$type/tbl";
	my($type) = $tbl_file =~ m,/([^/]+)/tbl$,;
	print STDERR "Load $type\n" if $ENV{VERBOSE};
	if (open(my $fh, "<", $tbl_file))
	{
	    while (defined(my $x = <$fh>))
	    {
		chomp $x;
		if ($x =~ /^(\S+)\t(\S+)(\t(\S.*\S))?/)
		{
		    my $fid = $1;
		    my $loc = [split(/,/,$2)];
		    my($contig) = $loc->[0] =~ /^(.*)_\d+_\d+$/;
		    my $aliases = $4 ? [split(/\t/,$4)] : [];
		    if (! $self->is_deleted_fid($fid))
		    {
			$tbl->{$fid} = [$loc,$aliases];
			if ($type eq 'peg' && $contig ne $cur_contig)
			{
			    push(@$contig_entries, [$contig, $fid]);
			    $cur_contig = $contig;
			}
		    }
		}
		else {
		    warn "Bad feature line in $newGdir:$x:\n";
		}
	    }
	    close($fh);
	}
	else
	{
	    warn "Cannot open $tbl_file: $!";
	}
    }
    print STDERR ("Loaded ", (scalar keys %$tbl), " features from $newGdir\n") if $ENV{FIG_VERBOSE};

    $self->{_contig_entrypoints} = $contig_entries;
    
    $self->{_tbl} = $tbl;
}

sub load_functions {
    my($self, $force) = @_;

    if (!$force && $self->{_functions}) { return };

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};
    my $functions = {};
    my $roles     = {};

    # order of "cat" is important - proposed_user_functions must be last
    
    opendir(my $dh, $newGdir);
    my @fn_files = map { "$newGdir/$_" } sort grep { /functions$/ } readdir($dh);
    closedir($dh);
    for my $fn_file (@fn_files)
#    for my $fn_file (<$newGdir/*functions>)
    {
	if (open(my $fh, "<", $fn_file))
	{
	    while (defined(my $x = <$fh>))
	    {
		if (($x =~ /^(fig\|(\d+\.\d+)\.\S+)\t(\S[^\t]*\S)/) && ($2 eq $newG))
		{
		    my $peg = $1;
		    my $f = $3;
		    if (! $self->is_deleted_fid($peg))
		    {
			# user has overridden a function, so delete old roles
			if (exists($functions->{$peg})) {
			    my @roles = &SeedUtils::roles_of_function($functions->{$peg});
			    foreach $_ (@roles)
			    {
				delete $roles->{$_};
			    }
			}
			
			# add new roles
			my @roles = &SeedUtils::roles_of_function($f);
			foreach $_ (@roles)
			{
			    push(@{$roles->{$_}},$peg);
			}
			
			# set function
			$functions->{$peg} = $f;
		    }
		}
	    }
	    close($fh);
	}
	else
	{
	    warn "Cannot open $fn_file: $!";
	}
    }
    $self->{_functions} = $functions;
    $self->{_roles} = $roles;
}

sub seqs_with_role {
    my($self,$role,$who,$genome) = @_;

    my $newG    = $self->{_genome};
    if ($genome && $newG && ($genome eq $newG)) {
	&load_functions($self);
    	my $pegsL = $self->{_roles}->{$role};	
	return ($pegsL ? @{$pegsL} : ());
    }
    return ();
}
 
sub load_ann {
    my($self) = @_;

    if ($self->{_ann}) { return };

    my $newGdir = $self->{_orgdir};
    my $ann     = {};
    if (open(ANN,"<$newGdir/annotations"))
    {
	$/ = "\n//\n";
	while (defined(my $x = <ANN>))
	{
	    chomp $x;
	    if ($x =~ /^(\S+)\n([^\n]+)\n([^\n]+)\n(.*)/s)
	    {
		push(@{$ann->{$1}},[$1,$2,$3,"$4\n"]);
	    }
	}
	$/ = "\n";
	close(ANN);
    }
    $self->{_ann} = $ann;
}

sub taxonomy_of {
    my($self) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    my $tax;
    if (open(TAX,"<$newGdir/TAXONOMY") && ($tax = <TAX>))
    {
	chop $tax;
	return $tax;
    }
    else
    {
	return "unknown";
    }
}

sub is_deleted_fid
{
    my($self, $fid) = @_;
    my $newG    = $self->{_genome};

    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 eq $newG))
    {
	my $delH;
	$delH = $self->{_deleted_features};
	if (! $delH)
	{
	    $delH = $self->load_deleted_features_hash();
	}
	return $delH->{$fid} ? 1 : 0;
    }
    return 0;
}

sub load_correspondences
{
    my($self) = @_;

    #return if exists($self->{correspondence_index});
    
    my $dir = $self->{_orgdir};
    my $index = {};
    my $rev_index = {};
    
    opendir(my $dh, "$dir/CorrToReferenceGenomes");
    my @corr_files = map { "$dir/CorrToReferenceGenomes/$_" } sort grep { /^\d+\.\d+$/ } readdir($dh);
    closedir($dh);
    for my $cfile (@corr_files)
#    for my $cfile (<$dir/CorrToReferenceGenomes/*>)
    {
	if ($cfile =~ m,/\d+\.\d+$,)
	{
	    if (open(my $fh, "<", $cfile))
	    {
		while (<$fh>)
		{
		    my $ent = CorrTableEntry->new($_);
		    push(@{$index->{$ent->id1}}, $ent);
		    push(@{$rev_index->{$ent->id2}}, $ent);
		}
		close($fh);
	    }
	    else
	    {
		warn "Could not open $cfile: $!\n";
	    }
	}    
    }
    $self->{correspondence_index} = $index;
    $self->{correspondence_index_rev} = $rev_index;
}

sub get_correspondences
{
    my($self, $id) = @_;

    $self->load_correspondences();

    return $self->{correspondence_index}->{$id};
}

sub get_correspondences_rev
{
    my($self, $id) = @_;

    $self->load_correspondences();

    return $self->{correspondence_index_rev}->{$id};
}

sub get_best_correspondences
{
    my($self, $id, $cutoff) = @_;
    my $corrs = $self->get_correspondences($id);

    my $lg;
    my $out = [];

    for my $hit (sort { SeedUtils::genome_of($a->id2) <=> SeedUtils::genome_of($b->id2) or
			$a->psc <=> $b->psc }
		 grep { (!defined($cutoff) or $_->psc < $cutoff) and
			($_->hitinfo eq '<=>' or SeedUtils::strip_func_comment($_->func1) eq SeedUtils::strip_func_comment($_->func2)) }
		 @$corrs)
    {
	if (defined($lg) && $lg ne SeedUtils::genome_of($hit->id2))
	{
	    push(@$out, $hit);
	}
	$lg = SeedUtils::genome_of($hit->id2);
    }
    return $out;

}

sub get_pin
{
    my($self, $peg, $n, $cutoff) = @_;

    my $hits = $self->get_best_correspondences($peg, $cutoff);
#    print join("\t", $_->id2, $_->func2) . "\n" for @$hits;
    my @pegs = map { $_->id2 }
    		 sort { $b->bsc <=> $a->bsc or
			abs($a->len1 - $a->len2) <=> abs($b->len1 - $b->len2) }
                 @$hits;
    $#pegs = ($n - 1) if @pegs > $n;
    return \@pegs;
}

sub get_context
{
    my($self, $peg, $pin, $width) = @_;

    #
    # Determine local context.
    #

    my $peg_loc = $self->feature_location($peg);
    my ($contig, $min, $max, $dir) = &SeedUtils::boundaries_of($peg_loc);
    my $center = ($min + $max) / 2;

    my ($my_genes, $minV, $maxV) = $self->genes_in_region($contig,
							  int($center - $width / 2),
							  int($center + $width / 2));

#    my $left_extent = $center - $minV;
#    my $right_extent = $maxV - $center;
    my $left_extent = int($width / 2);
    my $right_extent = int($width / 2);

    #
    # Determine other context. Get locations for the pin, then find the
    # regions.
    #
    my $sap = $self->{_sap};
    if (!defined($sap))
    {
	$sap = $self->{_sap} = SAPserver->new($pseed_url);
    }

    my $genome_names = $sap->genome_names(-ids => [map { &SeedUtils::genome_of($_) } @$pin]);
    my $my_genome = $self->genus_species;
    $my_genome = $self->genome_id if $my_genome eq '';
	
    $genome_names->{SeedUtils::genome_of($peg)} = $my_genome;
    
    my $locs = $sap->fid_locations(-ids => $pin, -boundaries => 1);

    my @extended_locs;
    for my $lpeg (keys %$locs)
    {
	my $loc = $locs->{$lpeg};
	my($lcontig, $lmin, $lmax, $ldir) = &SeedUtils::boundaries_of($loc);
	my $center = ($lmin + $lmax) / 2;
	my $left_end = int($center - $left_extent);
	$left_end = 0 if $left_end < 0;
	my $right_end = int($center + $right_extent);
	push(@extended_locs, &SeedUtils::location_string($lcontig, $left_end, $right_end));
    }

    my $regions = $sap->genes_in_region(-locations => \@extended_locs, -includeLocation => 1);

    #
    # Determine functions.
    #
    my @ext_pegs = map { keys %$_ } values %$regions;
    my $funcs = $sap->ids_to_functions(-ids => \@ext_pegs);

    #
    # Overlay with local functions.
    
    $funcs->{$_} = $self->function_of($_) for @$my_genes;

    #
    # We have the whole shebang now. We can assemble and return.
    #
    # Each genome is a list of genes.
    # Each gene is a list [fid, contig, beg, end, dir, func].
    #

    my @context;
    my $cref = {};
    my $row = 0;

    #
    # Start with local context.
    #
    
    my @loc = map { my($contig, $min, $max, $dir) = &SeedUtils::boundaries_of($self->feature_location($_));
		     [$_, $contig, $min, $max, $dir, $funcs->{$_}, $row] } @$my_genes;
    push @context, [ sort { $a->[2] <=> $b->[2] } @loc ];
    $cref->{$_->[0]} = $_ for @loc;

    $row++;
    #
    # And include the pinned region.
    #
    for my $loc (@extended_locs)
    {
	my $region = $regions->{$loc};
	my @row;
	for my $peg (keys %$region)
	{
	    my $func = defined($funcs->{$peg}) ? $funcs->{$peg} : "";
	    my($contig, $min, $max, $dir) = &SeedUtils::boundaries_of($region->{$peg});
	    my $ent = [$peg, $contig, $min, $max, $dir, $func, $row];
	    $cref->{$peg} = $ent;
	    push(@row, $ent);
	}
	$row++;

	push @context, [ sort { $a->[2] <=> $b->[2] } @row ];
    }

    return \@context, $cref, $genome_names;
}

sub add_feature {
    my( $self, $user, $genome, $type, $location, $aliases, $sequence) = @_;
  
    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if ($genome ne $newG) {
	return undef;
    }
    
    # perform sanity checks
    unless ($genome && $type && $location && $sequence) {
	print STDERR "SEED error: add_feature failed due to missing parameter\n";
	return undef;
    }

    if ( $type !~ /^[0-9A-Za-z_]+$/ )
    {
        print STDERR "SEED error: add_feature failed due to bad type: $type\n";
        return undef;
    }

    if ( length ( $location ) > 5000 )
    {
        print STDERR "SEED error: add_feature failed because location is over 5000 char:\n";
        print STDERR "$location\n";
        return undef;
    }

    my @loc  = split( /,/, $location );
    my @loc2 = grep { $_->[0] && $_->[1] && $_->[2] }    
               map  { [ $_ =~ m/^(.+)_(\d+)_(\d+)$/ ] }
               @loc;

    if ( (@loc2 == 0) || ( @loc != @loc2 ) )
    {
        print STDERR "SEED error: add_feature failed because location is missing or malformed:\n";
        print STDERR "$location\n";
        return undef;
    }

    if ( my @bad_names = grep { length( $_->[0] ) > 96 } @loc2 )
    {
        print STDERR "SEED error: add_feature failed because location contains a contig name of over 96 char:\n";
        print STDERR join( ", ", @bad_names ) . "\n";
        return undef;
    }

    # create type directory if it does not exist
    unless (-d "$newGdir/Features/$type") {
	&SeedUtils::verify_dir("$newGdir/Features/$type");
	(-d "$newGdir/Features/$type")
	    || die qq(Feature directory \'$newGdir/Features/$type\' does not exist, and could not be created);
	
	open(TMP, ">", "$newGdir/Features/$type/tbl")
	    || die "Could not create empty $newGdir/Features/$type/tbl: $!";
	close(TMP);
	
	open(TMP, ">", "$newGdir/Features/$type/fasta")
	    || die "Could not create empty $newGdir/Features/$type/fasta: $!";
	close(TMP);
    }
    
    # create an id
    my $id = "fig|$genome.$type.";
    my $feature_dir = "$newGdir/Features/$type";
    my $file = "$feature_dir/tbl";
    if (-f $file) {
	unless (open(FILE, "<$file")) {
	    print STDERR "SEED error: could not open tbl file: $@\n";
	    return undef;
	}
	my $entry;
        my $max = 0;
	while (defined($entry = <FILE>)) {
	    chomp $entry;
	    if ($entry =~ /^fig\|$genome\.$type\.(\d+)/) {
		my $curr_id = $1;
		if ($curr_id > $max) {
		    $max = $curr_id;
		}
	    }
	    else {
		confess qq(Could not parse $type tbl entry: $entry);
	    }
	}
	close FILE;
	++$max;
	$id .= $max;
    } else {
	$id .= "1";
    }
    
    # append to tbl file
    unless (open(FILE, ">>$file")) {
	print STDERR "SEED error: could not open tbl file: $@\n";
	return undef;
    }
    
    $aliases =~ s/,/\t/g;
    print FILE "$id\t$location\t$aliases\n";
    close FILE;	
    chmod(0777,$file);

    my $typeH = $self->{_features}->{$type};
    if ($typeH)
    {
	$typeH->{$id} = 1;
    }

    my $tbl = $self->{_tbl};
    if ($tbl)
    {
	$tbl->{$id} = [[@loc],[split(/\t/,$aliases)]];
    }

    # append to fasta file
    $sequence =~ s/\s//g;
    
    $file = "$feature_dir/fasta";
    unless (open(FILE, ">>$file")) {
	print STDERR "SEED error: could not open fasta file: $@\n";
	return undef;
    }
    print FILE ">$id\n$sequence\n";
    close FILE;
    chmod(0777,$file);

    # append to called_by file
    $file = "$newGdir/called_by";
    unless (open(FILE, ">>$file")) {
	print STDERR "SEED error: could not open called_by file: $@\n";
	return undef;
    }
    print FILE "$id\tmanual: $user\n";
    close FILE;
    chmod(0777,$file);

    #
    # If a btree was created for this, clear the ref to it and delete the files since
    # they are now invalid.
    #

    my $tie = $self->{_feat_tie}->{$type};
    my $btree = $self->{_feat_btree}->{$type};

    if ($tie)
    {
	untie $tie;
	delete $self->{$_}->{$type} for qw(_feat_tie _feat_btree _feat_ltie _feat_recno _feat_fasta);

	unlink("$feature_dir/tbl.btree");
	unlink("$feature_dir/tbl.recno");
    }

    if (-f "$feature_dir/fasta.norm.phr")
    {
# todo fix dangerous
	#unlink(<$feature_dir/fasta.norm.*>);
    }
	
    
    # declare success
    return $id;
}

sub delete_feature {
    my($self,$user,$fid) = @_;

    my $newG    = $self->{_genome};
    my $newGdir = $self->{_orgdir};

    if (($fid =~ /^fig\|(\d+\.\d+)/) && ($1 ne $newG))
    {
	warn "delete_feature on non-seedv fid\n";
	return 0;
    }

    if (open(DEL,">>$newGdir/deleted.fids"))
    {
	print DEL "$fid\t$user\n";
	close(DEL);
	$self->load_deleted_features_hash();
    }
    else
    {
	carp "could not open $newGdir/deleted.fids: failed to delete $fid (user=$user)\n";
    }
}

sub load_deleted_features_hash {
    my($self) = @_;

    my $newGdir = $self->{_orgdir};
    my $deletedH = {};
    if (open(DEL,"<$newGdir/deleted.fids"))
    {
	local $/ = "\n";
        while (<DEL>)
	{
	    if ($_ =~ /^(\S+)/)
	    {
		$deletedH->{$1} = 1;
	    }
	}
	close(DEL);
    }
    $self->{_deleted_features} = $deletedH;

    return $deletedH;
}

#
# List of feature types that exist in this genome.
#
sub feature_types
{
    my($self) = @_;

    my $newGdir = $self->{_orgdir};

    my %sort_prefs = (peg => 2,
		      rna => 1);

    if (opendir(my $dh, "$newGdir/Features"))
    {
	my @types = grep { ! /^\./ && -d "$newGdir/Features/$_" } readdir($dh);
	closedir($dh);
	return sort { $sort_prefs{$b} <=> $sort_prefs{$a} or $a cmp $b } @types;
    }
    return ();
}

sub write_features_for_comparison
{
    my($self, $fh) = @_;

    for my $ent (@{$self->all_features_detailed_fast()})
    {
	my($fid, $loc, undef, $type, $min, $max, $fn) = @$ent;
	next unless $type eq 'peg';
	print $fh join("\t", $fid, $loc, $fn), "\n";
    }
}



1;
