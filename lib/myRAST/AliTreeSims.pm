# This is a SAS component.

#
# Copyright (c) 2003-2010 University of Chicago and Fellowship
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

package AliTreeSims;

#===============================================================================
#  perl functions for dealing with Similarities from Alignments and Trees.
#
#  Usage:  use AliTreeSims;
#
#===============================================================================

use strict;
use gjonewicklib;
use gjoseqlib;
use AlignsAndTreesServer;
use SeedUtils;
use Sim;
use Data::Dumper;
# use Carp;
# use Time::HiRes qw(gettimeofday);
# use Time::Local;
use ffxtree;
require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
       md5_tree_sims_of_align
       md5_tree_sims
       peg_tree_sims
       merged_sims
       );

#
#  Field definitions:
#
#   0   id1        query sequence id
#   1   id2        subject sequence id
#   2   iden       percentage sequence identity
#   3   ali_ln     alignment length
#   4   mismatches  number of mismatch
#   5   gaps       number of gaps
#   6   b1         query seq match start
#   7   e1         query seq match end
#   8   b2         subject seq match start
#   9   e2         subject seq match end
#  10   psc        match e-value
#  11   bsc        bit score
#  12   ln1        query sequence length
#  13   ln2        subject sequence length
#  14   tool       tool used to produce similarities
#
#  All following fields may vary by tool:
#
#  15   loc1       query seq locations string (b1-e1,b2-e2,b3-e3)
#  16   loc2       subject seq locations string (b1-e1,b2-e2,b3-e3)
#  17   dist       tree distance
#

sub distance_based_sim
{
    my ( $id1, $data1, $id2, $data2, $dist, $dbsize ) = @_;
    $dbsize ||= 1e9;

    my ( $len1, $b1, $e1, $loc1 ) = @$data1;
    my ( $len2, $b2, $e2, $loc2 ) = @$data2;
    my $npos1 = location_length( $loc1 );
    my $npos2 = location_length( $loc2 );

    my $ident     = 0.85 * exp( -$dist ) + 0.15;
    my $align_len = $npos1 > $npos2 ? $npos1 : $npos2;
    my $mismatch  = int( $align_len * ( 1 - $ident ) );
    my $gaps      = abs( $npos1 - $npos2 );

    my $nbitscr_max   =  2.10;
    my $nbitscr_decay = -0.47;
    my $nbitscr       = $nbitscr_max * exp( $nbitscr_decay * $dist );
    my $bitscr        = $nbitscr * $align_len;

    my $eff_qlen = $npos1 - 30;
    $eff_qlen    = 30 if $eff_qlen < 30;
    my $evalue   = $eff_qlen * $dbsize * exp( -$bitscr * log( 2 ) );

    my $sim = [ $id1, $id2,
                sprintf( '%.1f', 100*$ident ),
                $align_len,
                $mismatch,
                $gaps,
                $b1, $e1, $b2, $e2,
                sprintf( "%.1e", $evalue ),
                sprintf( "%.1f", $bitscr ),
                $len1, $len2,
                'tree distance',
                $loc1, $loc2, $dist
              ];

    bless $sim, 'Sim';
}

sub location_length
{
    my $len = 0;
    foreach ( split /,/, $_[0] ) { $len += ($2-$1)+1 if /^(\d+)-(\d+)/ }
    $len;
}

#-------------------------------------------------------------------------------
#  md5_tree_sims_of_align
#
#     @md5_sims = md5_tree_sims_of_align( $treeID, $md5 );
#    \@md5_sims = md5_tree_sims_of_align( $treeID, $md5 );
#
#  Returns sims format similarities from the tree.
#-------------------------------------------------------------------------------
sub md5_tree_sims_of_align
{
    my( $treeID, $id1 ) = @_;
    defined( $treeID ) && $id1 or return wantarray ? () : [];

    my $md5_tree = AlignsAndTreesServer::md5_tree_by_ID( $treeID );
    $md5_tree or return wantarray ? () : [];

    my $to_distH = ffxtree::distances_from_tip( $md5_tree, $id1 );
    my $to_infoH = AlignsAndTreesServer::md5_alignment_metadata( $treeID );

    my $info1 = $to_infoH->{ $id1 } or return wantarray ? () : [];
    my ( undef, undef, $ln1, $b1, $e1, $loc1 ) = @$info1;

    my @md5_sims;
    push @md5_sims, distance_based_sim( $id1, $info1, $id1, $info1, 0 );

    foreach my $id2 ( keys %$to_distH )
    {
        my $info2 = $to_infoH->{ $id2 } or next;
        push @md5_sims, distance_based_sim( $id1, $info1, $id2, $info2, $to_distH->{ $id2 } );
    }

    wantarray ? @md5_sims : \@md5_sims;
}


#-------------------------------------------------------------------------------
#  md5_tree_sims
#
#     @md5_sims = md5_tree_sims( $md5 );
#    \@md5_sims = md5_tree_sims( $md5 );
#
#  Returns tree-based sims for given a md5.
#-------------------------------------------------------------------------------
sub md5_tree_sims
{
    my ( $md5 ) = @_;
    $md5 or return wantarray ? () : [];

    my @md5_sims;
    foreach my $treeID ( AlignsAndTreesServer::trees_with_md5ID( $md5 ) )
    {
        push @md5_sims, md5_tree_sims_of_align( $treeID, $md5 );
    }

    my %seen_id2;
    my @md5_sims = grep { ! $seen_id2{ $_->id2 }++ }
                   sort { $b->bsc <=> $a->bsc }
                   @md5_sims;

    wantarray ? @md5_sims : \@md5_sims;
}


#-------------------------------------------------------------------------------
#  peg_tree_sims
#
#     @peg_tree_sims = peg_tree_sims( $fid );
#    \@peg_tree_sims = peg_tree_sims( $fid );
#
#  Returns tree-based sims for given a peg fid.
#-------------------------------------------------------------------------------
sub peg_tree_sims
{
    my ( $fid ) = @_;
    $fid or return wantarray ? () : [];

    my $md5 = AlignsAndTreesServer::peg_to_md5( $fid );
    $md5 or return wantarray ? () : [];

    my @peg_sims = map { my $id2 = $_->id2;
                         my $md5_sim = $_;
                         map { my $peg_sim = [ @$md5_sim ];
                               $peg_sim->[0] = $fid;
                               $peg_sim->[1] = $_;
                               $_ ne $fid ? ( bless $peg_sim, 'Sim' ) : ();
                             } AlignsAndTreesServer::md5_to_pegs( $id2 );
                       }
                   md5_tree_sims( $md5 );

    wantarray ? @peg_sims : \@peg_sims;
}


#-------------------------------------------------------------------------------
#    @sims = dereplicate_sims( \@sims, ... )
#   \@sims = dereplicate_sims( \@sims, ... )
#    maximum fraction overlap = 0.5
#-------------------------------------------------------------------------------

sub dereplicate_sims
{
    my $max_frac_overlap;

    my %sims_by_id2;
    foreach ( @_ )
    {
        foreach ( @$_ ) { push @{ $sims_by_id2{ $_->id2 } }, $_ }
    }

    my @sims;
    foreach ( values %sims_by_id2 )
    {
        ( push @sims, $_->[0] and next ) if @$_ == 1;

        my ( $sim, @id2_sims ) = sort { $b->bsc <=> $a->bsc } @$_;
        push @sims, $sim;
        my @covered = ( [ $sim->b2, $sim->e2 ] );

        foreach $sim ( @id2_sims )
        {
            my $b = $sim->b2;
            my $e = $sim->e2;
            my $max_overlap = $max_frac_overlap * ( $e - $b + 1 );
            my $keep = 1;
            foreach my $cov ( @covered )
            {
                my $overlap = min( $e, $cov->[1] ) - max( $b, $cov->[0] ) + 1;
                if ( $overlap > $max_overlap ) { $keep = 0; last }
            }

            if ( $keep )
            {
                push @sims, $sim;
                push @covered, [ $b, $e ];
            }
        }
    }

    @sims = sort { $b->bsc <=> $a->bsc } @sims;

    wantarray ? @sims : \@sims;
}

sub min    { $_[0] < $_[1] ? $_[0] : $_[1] }
sub max    { $_[0] > $_[1] ? $_[0] : $_[1] }

#-------------------------------------------------------------------------------
#  merged_sims
#
#     @sims= merged_sims( $fid, \%options );
#    \@sims= merged_sims( $fid, \%options );
#
#  Options:
#
#      max_e_value  => $maximum_e_value
#      max_sims     => $maximum_count
#      min_identity => $minimum_identity
#      min_q_cover  => $minimum_q_cover
#      min_s_cover  => $minimum_s_cover
#
#  Returns lists of tree sims and regular sims for a fid.
#-------------------------------------------------------------------------------
sub merged_sims
{
    my( $fid, $options ) = @_;
    $fid or return wantarray ? () : [];
    $options = {} if $options || ref $options ne 'HASH';

    my $max_e_value  = $options->{ max_e_value }  || 1e-5;
    my $max_sims     = $options->{ max_sims }     || 5000;
    my $min_identity = $options->{ min_identity } ||    0;
    my $min_q_cover  = $options->{ min_q_cover }  ||    0;
    my $min_s_cover  = $options->{ min_s_cover }  ||    0;

    my @peg_sims     = peg_tree_sims( $fid );
    my @classic_sims = SeedUtils::sims( [ $fid ], $max_sims, $max_e_value, 'fig', 10000 );
    my @sims = dereplicate_sims( \@peg_sims, \@classic_sims );

    @sims = grep { $_->pval            <= $max_e_value           } @sims;
    @sims = grep { $_->ident           >= $min_identity          } @sims if $min_identity;
    @sims = grep { $_->e1 - $_->b1 + 1 >= $min_q_cover * $_->ln1 } @sims if $min_q_cover;
    @sims = grep { $_->e2 - $_->b2 + 1 >= $min_s_cover * $_->ln2 } @sims if $min_s_cover;

    splice @sims, $max_sims, @sims-$max_sims if @sims > $max_sims;

    wantarray ? @sims : \@sims;
}

1;
