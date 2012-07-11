# This is a SAS component
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

package gjoalignment;

#===============================================================================
#  A package of functions for alignments (to be expanded)
#
#    @align = align_with_clustal(  @seqs )
#    @align = align_with_clustal( \@seqs )
#    @align = align_with_clustal( \@seqs, \%opts )
#   \@align = align_with_clustal(  @seqs )
#   \@align = align_with_clustal( \@seqs )
#   \@align = align_with_clustal( \@seqs, \%opts )
#
#    @align = clustal_profile_alignment( \@seqs,  $seq )
#   \@align = clustal_profile_alignment( \@seqs,  $seq )
#    @align = clustal_profile_alignment( \@seqs, \@seqs )
#   \@align = clustal_profile_alignment( \@seqs, \@seqs )
#
#   \@align                           = align_with_muscle( \@seqs )
#   \@align                           = align_with_muscle( \@seqs, \%opts )
#   \@align                           = align_with_muscle( \%opts )
# ( \@align, $newick-tree-as-string ) = align_with_muscle( \@seqs )
# ( \@align, $newick-tree-as-string ) = align_with_muscle( \@seqs, \%opts )
# ( \@align, $newick-tree-as-string ) = align_with_muscle( \%opts )
#
#   \@align                           = align_with_mafft( \@seqs )
#   \@align                           = align_with_mafft( \@seqs, \%opts )
#   \@align                           = align_with_mafft( \%opts )
# ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs )
# ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs, \%opts )
# ( \@align, $newick-tree-as-string ) = align_with_mafft( \%opts )
#
#    $tree      = tree_with_clustal( \@alignment );
#
#    @alignment = add_to_alignment(     $seqentry, \@alignment );
#    @alignment = add_to_alignment_v2(  $seqentry, \@alignment, \%options );
#    @alignment = add_to_alignment_v2a( $seqentry, \@alignment, \%options );
#
#   \@alignment = bootstrap_sample( \@alignment );
#
#===============================================================================

use strict;
use gjoseqlib;
use SeedAware;
use Carp;                       # Used for diagnostics
eval { require Data::Dumper };  # Not present on all systems

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
        align_with_clustal
        clustal_profile_alignment
        align_with_muscle
        align_with_mafft
        add_to_alignment
        add_to_alignment_v2
        add_to_alignment_v2a
        bootstrap_sample
        );


#===============================================================================
#  Align sequences with muscle and return the alignment, or alignment and tree.
#
#     \@align                           = align_with_mafft( \@seqs )
#     \@align                           = align_with_mafft( \@seqs, \%opts )
#     \@align                           = align_with_mafft( \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \@seqs, \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_mafft( \%opts )
#
#  If input sequences are not supplied, they must be included as an in or in1
#  option value.
#
#  Options:
#
#     add       =>  $seq      #  Add one sequence to \@ali1 alignment
#     algorithm =>  linsi, einsi, ginsi, nwnsi, nwns, fftnsi, fftns (d)
#                             #  Algorithms in descending order or accuracy
#     in        => \@seqs     #  Input sequences; same as in1, or \@seqs
#     in1       => \@ali1     #  Input sequences; same as in, or \@seqs
#     in2       => \@ali2     #  Align \@seqs with \@ali2; same as profile, or seed
#     profile   => \@ali2     #  Align \@seqs with \@ali2; same as in2, or seed
#     seed      => \@ali2     #  Align \@seqs with \@ali2; same as in2, or profile
#     version   =>  $bool     #  Return the program version number, or undef
#
#  Many of the program flags can be used as keys (without the leading --).
#===============================================================================
sub align_with_mafft
{
    my( $seqs, $opts );
    if ( $_[0] && ref( $_[0] ) eq 'HASH' ) { $opts = shift }
    else                                   { ( $seqs, $opts ) = @_ }

    $opts = {} if ! $opts || ( ref( $opts ) ne 'HASH' );

    my $add      = $opts->{ add }      || undef;
    my $profile  = $opts->{ profile }  || $opts->{ in2 } || $opts->{ seed } || undef;
       $seqs   ||= $opts->{ seqs }     || $opts->{ in }  || $opts->{ in1 };
    my $version  = $opts->{ version }  || 0;

    my $mafft = SeedAware::executable_for( $opts->{ mafft } || $opts->{ program } || 'mafft' )
        or print STDERR "Could not locate executable file for 'mafft'.\n"
            and return undef;

    if ( $version )
    {
        my $tmpdir = SeedAware::location_of_tmp( $opts );
        my $tmpF   = SeedAware::new_file_name( "$tmpdir/version", '' );

        SeedAware::system_with_redirect( $mafft, "--help", { stderr => $tmpF } );
        open( MAFFT, $tmpF ) or die "Could not open $tmpF";
        my @info = <MAFFT>;
        close( MAFFT );
        unlink( $tmpF );

        $version = $info[2]; # second line of MAFFT usage info
        chomp( $version );
        return $version;
    }

    my %prog_val  = map { $_ => 1 }
                    qw( aamatrix
                        bl
                        ep
                        groupsize
                        jtt
                        lap
                        lep
                        lepx
                        LOP
                        LEXP
                        maxiterate
                        op
                        partsize
                        retree
                        tm
                        thread
                        weighti
                      );

    my %prog_flag = map { $_ => 1 }
                    qw( 6merpair
                        amino
                        auto
                        clustalout
                        dpparttree
                        fastapair
                        fastaparttree
                        fft
                        fmodel
                        genafpair
                        globalpair
                        inputorder
                        localpair
                        memsave
                        nofft
                        noscore
                        nuc
                        parttree
                        quiet
                        reorder
                        treeout
                      );

    my $degap = ! ( $add || $profile );
    my $tree  = ! ( $add || $profile );

    my $tmpdir = SeedAware::location_of_tmp( $opts );
    my $tmpin  = SeedAware::new_file_name( "$tmpdir/seqs",  'fasta' );
    my $tmpin2 = SeedAware::new_file_name( "$tmpdir/seqs2", 'fasta' );
    my $tmpout = SeedAware::new_file_name( "$tmpdir/ali",   'fasta' );

    if ( ! ( $seqs && ref($seqs) eq 'ARRAY' && @$seqs && ref($seqs->[0]) eq 'ARRAY' ) )
    {
        print STDERR "gjoalignment::align_with_mafft() called without sequences\n";
        return undef;
    }

    my ( $id, $seq, %comment );
    my @clnseq = map { ( $id, $seq ) = @$_[0,2];
                       $comment{ $id } = $_->[1] || '';
                       $seq =~ tr/A-Za-z//cd if $degap;  # degap
                       [ $id, '', $seq ]
                     }
                 @$seqs;
    gjoseqlib::print_alignment_as_fasta( $tmpin, \@clnseq );

    #  Adding one sequence is a special case of profile alignment

    if ( $add ) { $profile = [ $add ]; $degap = 1 }

    if ( $profile )
    {
        if ( ! ( ref($profile) eq 'ARRAY' && @$profile && ref($profile->[0]) eq 'ARRAY' ) )
        {
            print STDERR "gjoalignment::align_with_mafft() requested to do profile alignment without sequences\n";
            return undef;
        }

        my @clnseq2 = map { ( $id, $seq ) = @$_[0,2];
                            $comment{ $id } = $_->[1] || '';
                            $seq =~ tr/A-Za-z//cd if $degap;  # degap
                            [ $id, '', $seq ]
                          }
                      @$profile;

        gjoseqlib::print_alignment_as_fasta( $tmpin2, \@clnseq );
    }

    my @params = $profile ? ( '--seed', $tmpin, '--seed', $tmpin2, '/dev/null')
               :            ( '--treeout',                         $tmpin,    );

    my $algorithm = lc( $opts->{ algorithm } || $opts->{ alg } );
    if ( $algorithm )
    {
        delete $opts->{ $_ } for qw( localpair genafpair globalpair nofft fft retree maxiterate );

        if    ( $algorithm eq 'linsi' || $algorithm eq 'l' ) { $opts->{ localpair }  = 1; $opts->{ maxiterate } = 1000 }
        elsif ( $algorithm eq 'einsi' || $algorithm eq 'e' ) { $opts->{ genafpair }  = 1; $opts->{ maxiterate } = 1000 }
        elsif ( $algorithm eq 'ginsi' || $algorithm eq 'g' ) { $opts->{ globalpair } = 1; $opts->{ maxiterate } = 1000 }
        elsif ( $algorithm eq 'nwnsi'  )                     { $opts->{ retree }     = 2; $opts->{ maxiterate } = 2;   $opts->{ nofft } = 1 }
        elsif ( $algorithm eq 'nwns'   )                     { $opts->{ retree }     = 2; $opts->{ maxiterate } = 0;   $opts->{ nofft } = 1 }
        elsif ( $algorithm eq 'fftnsi' )                     { $opts->{ retree }     = 2; $opts->{ maxiterate } = 2;   $opts->{ fft }   = 1 }
        elsif ( $algorithm eq 'fftns'  )                     { $opts->{ retree }     = 2; $opts->{ maxiterate } = 0;   $opts->{ fft }   = 1 }
    }

    foreach ( keys %$opts )
    {
        @params = ("--$_", @params)               if $prog_flag{ $_ };
        @params = ("--$_", $opts->{$_}, @params)  if $prog_val{ $_ };
    }

    my $redirects = { stdout => $tmpout, stderr => '/dev/null' };
    SeedAware::system_with_redirect( $mafft, @params, $redirects );
    
    my @ali = &gjoseqlib::read_fasta( $tmpout );
    foreach $_ ( @ali ) { $_->[1] = $comment{$_->[0]} }

    my $treestr;
    my $treeF  = "$tmpin.tree";
    if ( $tree && open( TREE, "<$treeF" ) ) { $treestr = join( "", <TREE> ); close( TREE ) }
    if ( $opts->{ treeout } ) { SeedAware::system_with_redirect( "cp", $treeF, $opts->{ treeout } ) }

    unlink( $tmpin, $tmpout,
            ( $profile ? $tmpin2 : () ),
            ( $tree    ? $treeF  : () )
          );

    return wantarray ? ( \@ali, $treestr ) : \@ali;
}

#===============================================================================
#  Align sequences with muscle and return the alignment, or alignment and tree.
#
#     \@align                           = align_with_muscle( \@seqs )
#     \@align                           = align_with_muscle( \@seqs, \%opts )
#     \@align                           = align_with_muscle( \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_muscle( \@seqs )
#   ( \@align, $newick-tree-as-string ) = align_with_muscle( \@seqs, \%opts )
#   ( \@align, $newick-tree-as-string ) = align_with_muscle( \%opts )
#
#  If input sequences are not supplied, they must be included as an in or in1
#  option value.
#
#  Options:
#
#     add      =>  $seq      #  Add one sequence to \@ali1 alignment
#     in       => \@seqs     #  Input sequences; same as in1, or \@seqs
#     in1      => \@ali1     #  Input sequences; same as in, or \@seqs
#     in2      => \@ali2     #  Align \@seqs with \@ali2; same as profile
#     profile  => \@ali2     #  Align \@seqs with \@ali2; same as in2
#     refine   =>  $bool     #  Do not start from scratch
#     version  =>  $bool     #  Return the program version number, or undef
#
#  Many of the program flags can be used as keys (without the leading -).
#===============================================================================
sub align_with_muscle
{
    my( $seqs, $opts );
    if ( $_[0] && ref( $_[0] ) eq 'HASH' ) { $opts = shift }
    else                                   { ( $seqs, $opts ) = @_ }

    $opts = {} if ! $opts || ( ref( $opts ) ne 'HASH' );

    my $add      = $opts->{ add }      || undef;
    my $profile  = $opts->{ profile }  || $opts->{ in2 } || undef;
    my $refine   = $opts->{ refine }   || 0;
       $seqs   ||= $opts->{ seqs }     || $opts->{ in } || $opts->{ in1 };
    my $version  = $opts->{ version }  || 0;

    my $muscle = SeedAware::executable_for( $opts->{ muscle } || $opts->{ program } || 'muscle' )
        or print STDERR "Could not locate executable file for 'muscle'.\n"
            and return undef;

    if ( $version )
    {
        $version = SeedAware::run_gathering_output($muscle, "-version");
        chomp $version;
        return $version;
    }

    my %prog_val  = map { $_ => 1 }
                    qw( anchorspacing
                        center
                        cluster1
                        cluster2
                        diagbreak
                        diaglength
                        diagmargin
                        distance1
                        distance2
                        gapopen
                        log
                        loga
                        matrix
                        maxhours
                        maxiters
                        maxmb
                        maxtrees
                        minbestcolscore
                        minsmoothscore
                        objscore
                        refinewindow
                        root1
                        root2
                        scorefile
                        seqtype
                        smoothscorecell
                        smoothwindow
                        spscore
                        SUEFF
                        usetree
                        weight1
                        weight2
                      );

    my %prog_flag = map { $_ => 1 }
                    qw( anchors
                        brenner
                        cluster
                        dimer
                        diags
                        diags1
                        diags2
                        le
                        noanchors
                        quiet
                        sp
                        spn
                        stable
                        sv
                        verbose
                      );

    my $degap = ! ( $add || $profile || $refine );
    my $tree  = ! ( $add || $profile || $refine );

    my $tmpdir = SeedAware::location_of_tmp( $opts );
    my $tmpin  = SeedAware::new_file_name( "$tmpdir/seqs",  'fasta' );
    my $tmpin2 = SeedAware::new_file_name( "$tmpdir/seqs2", 'fasta' );
    my $tmpout = SeedAware::new_file_name( "$tmpdir/ali",   'fasta' );
    my $treeF  = SeedAware::new_file_name( "$tmpdir/ali",   'newick' );

    if ( ! ( $seqs && ref($seqs) eq 'ARRAY' && @$seqs && ref($seqs->[0]) eq 'ARRAY' ) )
    {
        print STDERR "gjoalignment::align_with_muscle() called without sequences\n";
        return undef;
    }

    my ( $id, $seq, %comment );
    my @clnseq = map { ( $id, $seq ) = @$_[0,2];
                       $comment{ $id } = $_->[1] || '';
                       $seq =~ tr/A-Za-z//cd if $degap;  # degap
                       [ $id, '', $seq ]
                     }
                 @$seqs;
    gjoseqlib::print_alignment_as_fasta( $tmpin, \@clnseq );

    #  Adding one sequence is a special case of profile alignment

    if ( $add ) { $profile = [ $add ]; $degap = 1 }

    if ( $profile )
    {
        if ( ! ( ref($profile) eq 'ARRAY' && @$profile && ref($profile->[0]) eq 'ARRAY' ) )
        {
            print STDERR "gjoalignment::align_with_muscle() requested to do profile alignment without sequences\n";
            return undef;
        }

        my @clnseq2 = map { ( $id, $seq ) = @$_[0,2];
                            $comment{ $id } = $_->[1] || '';
                            $seq =~ tr/A-Za-z//cd if $degap;  # degap
                            [ $id, '', $seq ]
                          }
                      @$profile;

        gjoseqlib::print_alignment_as_fasta( $tmpin2, \@clnseq );  # The zero is "do not compress"
    }

    my @params = $profile ? ( '-in1', $tmpin, '-in2', $tmpin2, '-out', $tmpout, '-profile' )
               : $refine  ? ( '-in1', $tmpin,                  '-out', $tmpout, '-refine' )
               :            ( '-in',  $tmpin,                  '-out', $tmpout, '-tree2', $treeF );

    foreach ( keys %$opts )
    {
        push @params, "-$_"               if $prog_flag{ $_ };
        push @params, "-$_", $opts->{$_}  if $prog_val{ $_ };
    }

    my $redirects = { stdout => '/dev/null', stderr => '/dev/null' };
    SeedAware::system_with_redirect( $muscle, @params, $redirects );

    my @ali = &gjoseqlib::read_fasta( $tmpout );
    foreach $_ ( @ali ) { $_->[1] = $comment{$_->[0]} }

    my $treestr;
    if ( $tree && open( TREE, "<$treeF" ) ) { $treestr = join( "", <TREE> ); close( TREE ) }

    unlink( $tmpin, $tmpout,
            ( $profile ? $tmpin2 : () ),
            ( $tree    ? $treeF  : () )
          );

    return wantarray ? ( \@ali, $treestr ) : \@ali;
}


#===============================================================================
#  Align sequence with clustalw and return the alignment
#
#    @align = align_with_clustal(  @sequences )
#    @align = align_with_clustal( \@sequences )
#    @align = align_with_clustal( \@sequences, \%opts )
#   \@align = align_with_clustal(  @sequences )
#   \@align = align_with_clustal( \@sequences )
#   \@align = align_with_clustal( \@sequences, \%opts )
#
#===============================================================================
sub align_with_clustal
{
    return wantarray ? [] : () if ! @_;        #  No input
    return wantarray ? [] : () if ref( $_[0] ) ne 'ARRAY';   #  Bad sequence entry

    my @seqs = ref( $_[0]->[0] ) eq 'ARRAY' ? @{ $_[0] } : @_;
    my $opts = ( $_[1] && ( ref( $_[1] eq 'HASH' ) ) ) ? $_[1] : {};

    return wantarray ? @seqs : \@seqs  if @seqs < 2;  # Just 1 sequence

    #  Remap the id to be clustal friendly, saving the originals in a hash:

    my ( $id, $def, $seq, $seq2, $id2, %desc, %seq, @seqs2 );

    #  CLUSTAL does not like long names, some characters in names, and
    #  odd symbols like * in sequences.

    $id2 = "seq000000";
    @seqs2 = map { $id  = $_->[0];
                   $def = ( ( @$_ == 3 ) && $_->[1] ) ? $_->[1] : '';
                   $desc{ ++$id2 } = [ $id, $def ];
                   $seq{ $id2 } = \$_->[-1];  #  Reference to original
                   $seq2 = $_->[-1];
                   $seq2 =~ s/\*/X/g;
                   $seq2 =~ tr/A-Za-z//cd;    #  Remove gaps
                   [ $id2, '', $seq2 ]        #  Sequences for clustal
                 } @seqs;

    #  Do the alignment:

    my $tmpdir  = SeedAware::location_of_tmp( $opts );
    my $seqfile = SeedAware::new_file_name( "$tmpdir/align_fasta",  'fasta' );
    my $outfile = SeedAware::new_file_name( "$tmpdir/align_fasta",  'aln' );
    my $dndfile = SeedAware::new_file_name( "$tmpdir/align_fasta",  'dnd' );

    gjoseqlib::print_alignment_as_fasta( $seqfile, \@seqs2 );

    my $clustalw = SeedAware::executable_for( $opts->{ clustalw } || $opts->{ program } || 'clustalw' )
        or print STDERR "Could not locate executable file for 'clustalw'.\n"
            and return undef;

    my @params = ( "-infile=$seqfile",
                   "-outfile=$outfile",
                   "-newtree=$dndfile",
                   '-outorder=aligned',
                   '-maxdiv=0',
                   '-align'
                 );
    my $redirects = { stdout => '/dev/null' };
    SeedAware::system_with_redirect( $clustalw, @params, $redirects );

    my @aligned = gjoseqlib::read_clustal_file( $outfile );
    unlink( $seqfile, $outfile, $dndfile );

    #  Restore the id and definition, and restore original characters to sequence:

    my @aligned2 = map { $id2 = $_->[0];
                         [ @{ $desc{$id2} }, fix_sequence( ${$seq{$id2}}, $_->[2] ) ]
                       }
                   @aligned;

    wantarray ? @aligned2 : \@aligned2;
}


#  Expand seq1 to match seq2:

sub fix_sequence
{
    my ( $seq1, $seq2 ) = @_;
    return $seq2 if $seq1 eq $seq2;
    my $seq2a = $seq2;
    $seq2a =~ s/-+//g;
    return $seq2 if $seq1 eq $seq2a;  # Same but for gaps in $seq2;

    #  Build the string character by character

    my $i = 0;
    $seq1 =~ s/-+//g;   # The following requires $seq1 to be gapfree
    join '', map { $_ eq '-' ? '-' : substr( $seq1, $i++, 1 ) } split //, $seq2;
}

#===============================================================================
#  Insert a new sequence into an alignment without altering the relative
#  alignment of the existing sequences.  The alignment is based on a profile
#  of those sequences that are not significantly less similar than the most
#  similar sequence.
#===============================================================================

sub add_to_alignment
{
    my ( $seq, $ali, $trim, $silent ) = @_;

    my $std_dev = 1.5;  #  The definition of "not significantly less similar"

    #  Don't add a sequence with a duplicate id.  This used to be fatal.

    my $id = $seq->[0];
    foreach ( @$ali )
    {
        next if $_->[0] ne $id;
        if (! $silent)
        {
            print STDERR "Warning: add_to_alignment not adding sequence with duplicate id:\n$id\n";
        }
        return wantarray ? @$ali : $ali;
    }

    #  Put sequences in a clean canonical form:

    my $type = guess_seq_type( $seq->[2] );
    my $clnseq = [ "seq000000", '', clean_for_clustal( $seq->[2], $type ) ];
    $clnseq->[2] =~ s/[^A-Z]//g;   # remove gaps
    my @clnali = map { [ $_->[0], '', clean_for_clustal( $_->[2], $type ) ] } @$ali;

    my( $trimmed_start, $trimmed_len );
    if ( $trim )    #### if we are trimming sequences before inserting into the alignment
    {
        ( $clnseq, $trimmed_start, $trimmed_len ) = &trim_with_blastall( $clnseq, \@clnali );
        if (! defined( $clnseq ) )
        {
            print STDERR "Warning: attempting to add a sequence with no recognizable similarity: $id\n";
            return $ali;
        }
    }

    #  Tag alignment sequences with similarity to new sequence and sort:

    my @evaluated = sort { $b->[0] <=> $a->[0] }
                    map  { [ fract_identity( $_, $clnseq ), $_ ] }
                    @clnali;

    #  Compute identity threshold from the highest similarity:

    my $threshold = identity_threshold( $evaluated[0]->[0],
                                        length( $evaluated[0]->[1]->[2] ),
                                        $std_dev
                                      );
    my $top_hit = $evaluated[0]->[1]->[0];

    #  Filter sequences for those that pass similarity threshold.
    #  Give them clustal-friendly names.

    my $s;
    $id = "seq000001";
    my @relevant = map  { [ $id++, "", $_->[1]->[2] ] }
                   grep { ( $_->[0] >= $threshold ) }
                   @evaluated;

    #  Do the profile alignment:

    my $tmpdir  = SeedAware::location_of_tmp( );
    my $profile = SeedAware::new_file_name( "$tmpdir/add_to_align_1", 'fasta' );
    my $seqfile = SeedAware::new_file_name( "$tmpdir/add_to_align_2", 'fasta' );
    my $outfile = SeedAware::new_file_name( "$tmpdir/add_to_align",   'aln' );
    ( my $dndfile = $profile ) =~ s/fasta$/dnd/;  # The program ignores our name

    gjoseqlib::print_alignment_as_fasta( $profile, \@relevant );
    gjoseqlib::print_alignment_as_fasta( $seqfile, [ $clnseq ] );
    #
    #  I would have thought that the profile tree file should be -newtree1, but
    #  that fails.  -newtree works fine at putting the file where we want it.
    #  Perhaps it would have made more sense to do a cd to the desired directory
    #  first.
    #
    my $clustalw = SeedAware::executable_for( 'clustalw' )
        or print STDERR "Could not locate executable file for 'clustalw'.\n"
            and return undef;

    my @params = ( "-profile1=$profile",
                   "-profile2=$seqfile",
                   "-outfile=$outfile",
                   "-newtree=$dndfile",
                   '-outorder=input',
                   '-maxdiv=0',
                   '-profile'
                 );
    my $redirects = { stdout => '/dev/null' };
    SeedAware::system_with_redirect( $clustalw, @params, $redirects );

    my @relevant_aligned = map { $_->[2] } gjoseqlib::read_clustal_file( $outfile );

    unlink( $profile, $seqfile, $outfile, $dndfile );

    my $ali_seq = pop @relevant_aligned;

    #  Figure out where the gaps were added to the existing alignment:

    my ( $i, $j, $c );
    my $jmax = length( $relevant_aligned[0] ) - 1;
    my @rel_seqs = map { $_->[2] } @relevant; # Save a level of referencing;
    my @to_add = ();

    for ( $i = $j = 0; $j <= $jmax; $j++ ) {
        $c = same_col( \@rel_seqs, $i, \@relevant_aligned, $j ) ? "x" : "-";
        push @to_add, $c;
        if ( $c ne "-" ) { $i++ }
    }
    my $mask = join( '', @to_add );

    #  Time to expand the sequences; we will respect case and non-standard
    #  gap characters.  We will add new sequence immediately following the
    #  top_hit.

    my $def;
    my @new_align = ();

    foreach my $entry ( @$ali )
    {
        ( $id, $def, $s ) = @$entry;
        push @new_align, [ $id, $def, gjoseqlib::expand_sequence_by_mask( $s, $mask ) ];
        if ( $id eq $top_hit )
        {
            my( $new_id, $new_def, $new_s ) = @$seq;
            if ( $trim ) { $new_s = substr( $new_s, $trimmed_start, $trimmed_len ) }
            #  Add gap characters to new sequence:
            my $new_mask = gjoseqlib::alignment_gap_mask( $ali_seq );
            push @new_align, [ $new_id, $new_def, gjoseqlib::expand_sequence_by_mask( $new_s, $new_mask ) ];
        }
    }

    @new_align = &final_trim( $seq->[0], \@new_align ) if $trim;

    wantarray ? @new_align : \@new_align;
}


#===============================================================================
#  Insert a new sequence into an alignment without altering the relative
#  alignment of the existing sequences.  The alignment is based on a profile
#  of those sequences that are not significantly less similar than the most
#  similar sequence.  This differs from v2 in that it removes the shared gap
#  columns in the subset of sequences before doing the profile alignment.
#
#    \@align = add_to_alignment_v2( $seq, \@ali, \%options )
#
#  Options:
#
#     trim   => bool     # trim sequence start and end
#     silent => bool     # no information messages
#     stddev => float    # window of similarity to include in profile (D = 1.5)
#
#===============================================================================

sub add_to_alignment_v2
{
    my ( $seq, $ali, $options ) = @_;

    $options = {} if ! $options || ( ref( $options ) ne 'HASH' );

    my $silent  = $options->{ silent }
               || ( defined $options->{ verbose } ? ! $options->{ verbose } : 0 );
    my $std_dev = $options->{ stddev } || 1.5;  #  The definition of "not significantly less similar"
    my $trim    = $options->{ trim }   || 0;

    #  Don't add a sequence with a duplicate id.

    my $id = $seq->[0];
    foreach ( @$ali )
    {
        next if $_->[0] ne $id;
        print STDERR "Warning: add_to_alignment_v2 not adding sequence with duplicate id:\n$id\n" if ! $silent;
        return wantarray ? @$ali : $ali;
    }

    #  Put sequences in a clean canonical form and give them clustal-friendly
    #  names (first sequence through the map {} is the sequence to be added):

    my %id_map;
    $id = "seq000000";
    ( $seq ) = gjoseqlib::pack_sequences( $seq );
    my $type = guess_seq_type( $seq->[2] );
    my ( $clnseq, @clnali ) = map { $id_map{ $_->[0] } = $id;
                                    [ $id++, "", clean_for_clustal( $_->[2], $type ) ]
                                  }
                              ( $seq, @$ali );
    my %clnali = map { $_->[0] => $_ } @clnali;

    if ( $trim )    #### if we are trimming sequences before inserting into the alignment
    {
        my( $trimmed_start, $trimmed_len );
        ( $clnseq, $trimmed_start, $trimmed_len ) = trim_with_blastall( $clnseq, \@clnali, $type );
        if ( ! defined( $clnseq ) )
        {
            print STDERR "Warning: attempted to add a sequence with no recognizable similarity: $id\n";
            return $ali;
        }
        $seq->[2] = substr( $seq->[2], $trimmed_start, $trimmed_len );
    }

    my @relevant = @clnali;
    my @prof_ali;
    my $done  = 0;
    my $cycle = 0;
    my $m1;
    my $added;
    my $top_hit;

    print STDERR join( '', "Adding $seq->[0]", $seq->[1] ? " $seq->[1]\n" : "\n" ) if ! $silent;

    while ( ! $done )
    {
        #  Do profile alignment on the current set:

        my $n = @relevant;
        print STDERR "   Aligning on a profile of $n sequences.\n" if ! $silent;

        $m1 = gjoseqlib::alignment_gap_mask( \@relevant );
        my $ali_on = gjoseqlib::pack_alignment_by_mask( $m1, \@relevant );

        @prof_ali = clustal_profile_alignment_0( $ali_on, $clnseq );

        # gjoseqlib::print_alignment_as_fasta( "add_2_align_clean_$cycle.aln", $clnseq );
        # gjoseqlib::print_alignment_as_fasta( "add_2_align_prof_$cycle.aln",  $ali_on );
        # gjoseqlib::print_alignment_as_fasta( "add_2_align_raw_$cycle.aln", \@prof_ali ); ++$cycle;

        $added = pop @prof_ali;

        #  Tag alignment sequences with similarity to new sequence and sort:

        my @evaluated = sort { $b->[0] <=> $a->[0] }
                        map  { [ fraction_identity( $_->[2], $added->[2], $type ), $_ ] }
                        @prof_ali;

        #  Compute identity threshold from the highest similarity:

        my $threshold = identity_threshold( $evaluated[0]->[0],
                                            length( $evaluated[0]->[1]->[2] ),
                                            $std_dev
                                          );

        #  Filter sequences for those that pass similarity threshold.

        @relevant = map  { $clnali{ $_->[1]->[0] } }    #  Clean copies
                    grep { ( $_->[0] >= $threshold ) }  #  Pass threshold
                    @evaluated;

        #  $top_hit is used to position the new sequence in the output alignment:

        $top_hit = $evaluated[0]->[1]->[0];

        $done = 1 if @relevant == @evaluated;  #  No sequences were discarded
    }

    #  Figure out where the gaps were added to the subset alignment, and to
    #  the new sequence:

    my $m2 = gjoseqlib::alignment_gap_mask( \@prof_ali );
    my $m3 = gjoseqlib::alignment_gap_mask(  $added );

    my ( $m4, $m5 ) = merge_alignment_information( $m1, $m2, $m3 );
    if ( $options->{ debug } )
    {
        my $m41 = $m4;
        my $m51 = $m5;
        $m41 =~ tr/\377//;
        print STDERR join( ', ', length($m4), $m41 =~ tr/\377//, length( $ali->[0]->[2] )), "\n";
        print STDERR join( ', ', length($m5), $m51 =~ tr/\377//, length( $seq->[2] )), "\n";
    }

    #  Time to expand the sequences; we will respect case and non-standard
    #  gap characters.  We will add new sequence immediately following the
    #  top_hit.

    my @new_align = ();

    foreach my $entry ( @$ali )
    {
        my ( $id, $def, $s ) = @$entry;
        push @new_align, [ $id, $def, gjoseqlib::expand_sequence_by_mask( $s, $m4 ) ];
        if ( $id_map{ $id } eq $top_hit )
        {
            #  Add gap characters to new sequence:
            my( $new_id, $new_def, $new_s ) = @$seq;
            push @new_align, [ $new_id, $new_def, gjoseqlib::expand_sequence_by_mask( $new_s, $m5 ) ];
        }
    }

    @new_align = &final_trim( $seq->[0], \@new_align ) if $trim;

    wantarray ? @new_align : \@new_align;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Build the alignment merging information for coverting the original alignment
#  and the added sequence into the final alignment.
#
#  ( $m4, $m5 ) = merge_alignment_information( $m1, $m2, $m3 )
#
#  The inputs are:
#
#     $m1 = the gaps removed from the original alignment to make the
#               profile of "relevant" sequences,
#     $m2 = the gaps that clustal introduced into the profile, and
#     $m3 = the gaps that clustal introduced into the added sequence.
#
#  The outputs are:
#
#     $m4 = the locations to add new gaps to the original alignment, and
#     $m5 = the locations to add gaps to the new sequence.
#
#  ali  rel
#  pos  pos  seq  m1  m2  m3  m4  m5
#   1    1    1    1   1   1   1   1
#   2    2    2    1   1   1   1   1
#   3    3    3    1   1   1   1   1
#   4              0           1   0
#   5              0           1   0
#   6    4    4    1   1   1   1   1
#   7    5    5    1   1   1   1   1
#   8    6    6    1   1   1   1   1
#   9         7    0   0   1   1   1
#  10         8    0   0   1   1   1
#  11              0           1   0
#  12    7    9    1   1   1   1   1
#  13    8   10    1   1   1   1   1
#  14    9         1   1   0   1   0
#  15   10         1   1   0   1   0
#  16   11   11    1   1   1   1   1
#            12        0   1   0   1
#            13        0   1   0   1
#  17   12   14    1   1   1   1   1
#  18   13   15    1   1   1   1   1
#
#
#  -----------------------------------------
#      length              number of 1s
#  -----------------------------------------
#  m1  length of ali       length of profile
#  m2  length of prof ali  length of profile
#  m3  length of prof ali  lenght of seq
#  m4  length of merge     length of ali
#  m5  length of merge     length of seq
#  -----------------------------------------
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub merge_alignment_information
{
    my ( $m1, $m2, $m3 ) = @_;
    my $i1max = length $m1;
    my $i2max = length $m2;
    my $i1 = 0;
    my $c1 = substr( $m1, $i1, 1 );
    my $i2 = 0;
    my $c2 = substr( $m2, $i2, 1 );
    my @m4;                      #  Mask for expanding original alignment
    my @m5;                      #  Mask for expanding new sequence
    while ( $i1 < $i1max || $i2 < $i2max )
    {
        if ( $c1 eq "\000" )      # ali column not in profile
        {
            if ( $c2 eq "\000" )  # new sequence restores column
            {
                push @m4, "\377";
                push @m5, "\377";
                $c1 = ( ++$i1 < $i1max ) ? substr( $m1, $i1, 1 ) : "\377";
                $c2 = ( ++$i2 < $i2max ) ? substr( $m2, $i2, 1 ) : "\377";
            }
            else
            {
                push @m4, "\377";
                push @m5, "\000";
                $c1 = ( ++$i1 < $i1max ) ? substr( $m1, $i1, 1 ) : "\377";
            }
        }
        else   # $c1 eq "\377"
        {
            if ( $c2 eq "\000" )  # new sequence adds a column
            {
                push @m4, "\000";
                push @m5, "\377";
                $c2 = ( ++$i2 < $i2max ) ? substr( $m2, $i2, 1 ) : "\377";
            }
            else
            {
                push @m4, "\377";
                push @m5, substr( $m3, $i2, 1 );
                $c1 = ( ++$i1 < $i1max ) ? substr( $m1, $i1, 1 ) : "\377";
                $c2 = ( ++$i2 < $i2max ) ? substr( $m2, $i2, 1 ) : "\377";
            }
        }
    }

    return ( join( '', @m4 ), join( '', @m5 ) );
}


#===============================================================================
#  Insert a new sequence into an alignment without altering the relative
#  alignment of the existing sequences.  The alignment is based on a profile
#  of those sequences that are not significantly less similar than the most
#  similar sequence.
#
#    \@align = add_to_alignment_v2a( $seq, \@ali, \%options )
#
#  Options:
#
#     trim   => bool     # trim sequence start and end
#     silent => bool     # no information messages
#     stddev => float    # window of similarity to include in profile (D = 1.5)
#
#===============================================================================

sub add_to_alignment_v2a
{
    my ( $seq, $ali, $options ) = @_;

    $options = {} if ! $options || ( ref( $options ) ne 'HASH' );

    my $trim    = $options->{ trim }   || 0;
    my $silent  = $options->{ silent } || 0;
    my $std_dev = $options->{ stddev } || 1.5;  #  The definition of "not significantly less similar"

    #  Don't add a sequence with a duplicate id.

    my $id = $seq->[0];
    foreach ( @$ali )
    {
        next if $_->[0] ne $id;
        print STDERR "Warning: add_to_alignment_v2 not adding sequence with duplicate id:\n$id\n" if ! $silent;
        return wantarray ? @$ali : $ali;
    }

    #  Put sequences in a clean canonical form and give them clustal-friendly
    #  names (first sequence through the map {} is the sequence to be added):

    my %id_map;
    $id = "seq000000";
    ( $seq ) = gjoseqlib::pack_sequences( $seq );
    my $type = guess_seq_type( $seq->[2] );
    my ( $clnseq, @clnali ) = map { $id_map{ $_->[0] } = $id;
                                    [ $id++, "", clean_for_clustal( $_->[2], $type ) ]
                                  }
                              ( $seq, @$ali );
    my %clnali = map { $_->[0] => $_ } @clnali;

    if ( $trim )    #### if we are trimming sequences before inserting into the alignment
    {
        my( $trimmed_start, $trimmed_len );
        ( $clnseq, $trimmed_start, $trimmed_len ) = trim_with_blastall( $clnseq, \@clnali, $type );
        if ( ! defined( $clnseq ) )
        {
            print STDERR "Warning: attempted to add a sequence with no recognizable similarity: $id\n";
            return $ali;
        }
        $seq->[2] = substr( $seq->[2], $trimmed_start, $trimmed_len );
    }

    my ( @prof_ali, $added, @evaluated );
    my @relevant = @clnali;

    my $done = 0;
    my $cycle = 0;
    while ( ! $done )
    {
        #  Do profile alignment on the current set:

        my $n = @relevant;
        print STDERR "   Aligning on a profile of $n sequences.\n" if ! $silent;

        @prof_ali = clustal_profile_alignment_0( \@relevant, $clnseq );
        # gjoseqlib::print_alignment_as_fasta( "add_2_align_raw_$cycle.aln", \@prof_ali ); ++$cycle;

        $added = pop @prof_ali;

        #  Tag alignment sequences with similarity to new sequence and sort:

        @evaluated = sort { $b->[0] <=> $a->[0] }
                     map  { [ fraction_identity( $_->[2], $added->[2], $type ), $_ ] }
                     @prof_ali;

        #  Compute identity threshold from the highest similarity:

        my $threshold = identity_threshold( $evaluated[0]->[0],
                                            length( $evaluated[0]->[1]->[2] ),
                                            $std_dev
                                          );

        #  Filter sequences for those that pass similarity threshold.

        @relevant = map  { $clnali{ $_->[1]->[0] } }    #  Clean copies
                    grep { ( $_->[0] >= $threshold ) }  #  Pass threshold
                    @evaluated;

        $done = 1 if @relevant == @evaluated;  #  No sequences were discarded
    }

    #  $top_hit is used to position the new sequence in the output alignment:

    my $top_hit = $evaluated[0]->[1]->[0];

    #  Figure out where the gaps were added to the input alignment:

    my $mask = added_gap_columns( \@relevant, \@prof_ali );

    #  Time to expand the sequences; we will respect case and non-standard
    #  gap characters.  We will add new sequence immediately following the
    #  top_hit.

    my @new_align = ();

    foreach my $entry ( @$ali )
    {
        my ( $id, $def, $s ) = @$entry;
        push @new_align, [ $id, $def, gjoseqlib::expand_sequence_by_mask( $s, $mask ) ];
        if ( $id_map{ $id } eq $top_hit )
        {
            #  Add gap characters to new sequence:
            my( $new_id, $new_def, $new_s ) = @$seq;
            my $new_mask = gjoseqlib::alignment_gap_mask( $added );
            push @new_align, [ $new_id, $new_def, gjoseqlib::expand_sequence_by_mask( $new_s, $new_mask ) ];
        }
    }

    @new_align = &final_trim( $seq->[0], \@new_align ) if $trim;

    wantarray ? @new_align : \@new_align;
}


#-------------------------------------------------------------------------------
#  Compare two otherwise identical alignments, finding columns of all gaps
#  that have been added to the second that are not in the first.  Added
#  columns are "\000" in output string (like columns to pack).  Other columns
#  are "\377".
#
#      $added_gaps = added_gap_columns( \@alignment1, \@alignment2 )
#
#-------------------------------------------------------------------------------
sub added_gap_columns
{
    return undef if ! ( $_[0] && ref( $_[0] ) eq 'ARRAY'
                     && $_[1] && ref( $_[1] ) eq 'ARRAY' );
    my $ali1gap = gjoseqlib::alignment_gap_mask( $_[0] );
    my $ali2gap = gjoseqlib::alignment_gap_mask( $_[1] );

    my $i1 = 0;
    for ( my $i2 = 0; $i2 < length( $ali2gap ); $i2++ )
    {
        #  Not a gap in align 2?
        if    ( substr( $ali2gap, $i2, 1 ) ne "\000" ) { $i1++ }
        #  Is also a gap in align 1?
        elsif ( substr( $ali1gap, $i1, 1 ) eq "\000" ) { $i1++; substr( $ali2gap, $i2, 1 ) = "\377" }
    }

    $ali2gap;
}


#-------------------------------------------------------------------------------
#  Align a sequence or profile to an existing profile.
#
#     \@alignment = clustal_profile_alignment( \@seqs,  $seq )
#     \@alignment = clustal_profile_alignment( \@seqs, \@seqs )
#
#-------------------------------------------------------------------------------
sub clustal_profile_alignment
{
    my ( $seqs1, $seqs2 ) = @_;

    $seqs1 && ref $seqs1 eq 'ARRAY' && @$seqs1 && $seqs1->[0] && ref $seqs1 eq 'ARRAY'
        or return ();
    $seqs2 && ref $seqs2 eq 'ARRAY' && @$seqs2
        or return ();
    $seqs2 = [ $seqs2 ] if ! ( ref $seqs2->[0] );

    $seqs1 = gjoseqlib::pack_alignment( $seqs1 );
    $seqs2 = gjoseqlib::pack_alignment( $seqs2 );

    #  Put sequences in a clean canonical form and give them clustal-friendly
    #  names (first sequence through the map {} is the sequence to be added):

    my $id = "seq000001";
    my $type = guess_seq_type( $seqs1->[2] );

    my %id_map;
    my @cln1 = map { $id_map{ $id } = $_; [ $id++, "", clean_for_clustal( $_->[2], $type ) ] }
               @$seqs1;

    my @cln2 = map { $id_map{ $id } = $_; [ $id++, "", clean_for_clustal( $_->[2], $type ) ] }
               @$seqs2;

    my @aln1 = clustal_profile_alignment_0( \@cln1, \@cln2 );
    my @aln2 = splice @aln1, @$seqs1;

    my @align;

    my $gap1 = gjoseqlib::alignment_gap_mask( \@aln1 );
    push @align, map { my ( $ori_id, $ori_def, $ori_seq ) = @{ $id_map{ $_->[0] } };
                       [ $ori_id, $ori_def, gjoseqlib::expand_sequence_by_mask( $ori_seq, $gap1 ) ]
                     }
                 @aln1; 

    my $gap2 = gjoseqlib::alignment_gap_mask( \@aln2 );
    push @align, map { my ( $ori_id, $ori_def, $ori_seq ) = @{ $id_map{ $_->[0] } };
                       [ $ori_id, $ori_def, gjoseqlib::expand_sequence_by_mask( $ori_seq, $gap2 ) ]
                     }
                 @aln2; 

    wantarray ? @align : \@align;
}


#-------------------------------------------------------------------------------
#  Align a sequence or profile to an existing profile.
#
#     \@alignment = clustal_profile_alignment_0( \@seqs,  $seq )
#     \@alignment = clustal_profile_alignment_0( \@seqs, \@seqs )
#
#  Assumes that ids and sequences are clustal friendly, so this is not really
#  a function for the outside world; use clustal_profile_alignment() instead.
#-------------------------------------------------------------------------------
sub clustal_profile_alignment_0
{
    my ( $seqs1, $seqs2 ) = @_;

    my $tmpdir  = SeedAware::location_of_tmp( );
    my $profile = SeedAware::new_file_name( "$tmpdir/add_to_align_1", 'fasta' );
    my $seqfile = SeedAware::new_file_name( "$tmpdir/add_to_align_2", 'fasta' );
    my $outfile = SeedAware::new_file_name( "$tmpdir/add_to_align",   'aln' );
    ( my $dndfile = $profile ) =~ s/fasta$/dnd/;  # The program ignores our name

    $seqs2 = [ $seqs2 ] if ! ( ref $seqs2->[0] );
    gjoseqlib::print_alignment_as_fasta( $profile, $seqs1 );
    gjoseqlib::print_alignment_as_fasta( $seqfile, $seqs2 );

    my $clustalw = SeedAware::executable_for( 'clustalw' )
        or print STDERR "Could not locate executable file for 'clustalw'.\n"
            and return undef;

    my @params = ( "-profile1=$profile",
                   "-profile2=$seqfile",
                   "-outfile=$outfile",
                   "-newtree=$dndfile",
                   '-outorder=input',
                   '-maxdiv=0',
                   '-profile'
                 );
    my $redirects = { stdout => '/dev/null' };
    SeedAware::system_with_redirect( $clustalw, @params, $redirects );

    #  2010-09-08: clustalw profile align can columns of all gaps; so pack it

    my @aligned = gjoseqlib::pack_alignment( gjoseqlib::read_clustal_file( $outfile ) );

    unlink( $profile, $seqfile, $outfile, $dndfile );

    wantarray ? @aligned : \@aligned;
}


#-------------------------------------------------------------------------------
#
#  remove dangling ends from $id
#
#-------------------------------------------------------------------------------
sub final_trim
{
    my( $id, $ali ) = @_;

    my $mask = gjoseqlib::alignment_gap_mask( grep { $_->[0] ne $id } @$ali );
    if ( $mask =~ /^\000*(\377.*\377)\000*$/ )
    {
        my $off = $-[1] || 0;
        my $end = $+[1] || length( $mask );

        if ( $off > 0 || $end < length( $mask ) )
        {
            foreach my $seq ( @$ali ) { $seq->[2] = substr( $seq->[2], $off, $end-$off ) }
        }
    }
    return @$ali;
}


sub clean_for_clustal
{
    my $seq  = uc shift;
    my $type = shift || 'p';
    if ( $type =~ m/^p/i )
    {
        $seq =~ tr/UBJOZ*/CXXXXX/;             # Sec -> Cys, other to X
    }
    else
    {
        $seq =~ tr/UEFIJLOPQXZ/TNNNNNNNNNN/;   # U -> T, other to N
    }
    $seq =~ s/[^A-Z]/-/g;     # Nonstandard gaps

    $seq
}


sub fract_identity
{
    my ( $seq1, $seq2 ) = @_;
    my ( $s1, $s2, $i, $same );

    my $tmpdir  = SeedAware::location_of_tmp( );
    my $infile  = SeedAware::new_file_name( "$tmpdir/fract_identity", 'fasta' );
    my $outfile = SeedAware::new_file_name( "$tmpdir/fract_identity", 'aln' );
    my $dndfile = SeedAware::new_file_name( "$tmpdir/fract_identity", 'dnd' );

    $s1 = $seq1->[2];
    $s1 =~ s/[^A-Za-z]+//g;
    $s2 = $seq2->[2];
    $s2 =~ s/[^A-Za-z]+//g;
    gjoseqlib::print_alignment_as_fasta( $infile, [ [ "s1", "", $s1 ], [ "s2", "", $s2 ] ] );

    my $clustalw = SeedAware::executable_for( 'clustalw' )
        or print STDERR "Could not locate executable file for 'clustalw'.\n"
            and return undef;

    my @params = ( "-infile=$infile",
                   "-outfile=$outfile",
                   "-newtree=$dndfile",
                   '-maxdiv=0',
                   '-align'
                 );
    my $redirects = { stdout => '/dev/null' };
    SeedAware::system_with_redirect( $clustalw, @params, $redirects );

    ( $s1, $s2 ) = map { $_->[2] } gjoseqlib::read_clustal_file( $outfile );  # just seqs

    unlink( $infile, $outfile, $dndfile );

    fraction_aa_identity( $s1, $s2 );
}


sub identity_threshold
{
    my ( $maxsim, $seqlen, $z ) = @_;
    $z = 1.5 if ! $z;
    my ( $p, $sigma, $step );

    $p = $maxsim / 2;
    $step = $p / 2;
    while ( $step > 0.0005 ) {
        $sigma = sqrt( $p * (1 - $p) / $seqlen );
        $p += ( $p + ( $z * $sigma ) < $maxsim ) ? $step : (- $step);
        $step /= 2;
    }
    return $p - $z * $sigma;
}


sub guess_seq_type
{
    my $seq = shift;
    $seq =~ tr/A-Za-z//cd;
    my $nt_cnt = $seq =~ tr/ACGTUacgtu//;
    ( $nt_cnt > ( 0.5 * length( $seq ) ) ) ? 'n' : 'p';
}


#===============================================================================
#  Compare two sequences for fraction identity.
#
#     $fract_id = fraction_identity( $seq1, $seq2, $type );
#     $fract_id = fraction_aa_identity( $seq1, $seq2 );
#     $fract_id = fraction_nt_identity( $seq1, $seq2 );
#
#  $type is 'p' or 'n' (D = p)
#===============================================================================
sub fraction_identity
{
    my $prot = ( $_[2] && ( $_[2] =~ m/^n/i ) ) ? 0 : 1;
    my ( $npos, $nid ) = $prot ? gjoseqlib::interpret_aa_align( @_[0,1] )
                               : gjoseqlib::interpret_nt_align( @_[0,1] );
    ( $npos > 0 ) ? $nid / $npos : undef
}

sub fraction_aa_identity
{
    my ( $npos, $nid ) = gjoseqlib::interpret_aa_align( @_[0,1] );
    ( $npos > 0 ) ? $nid / $npos : undef
}

sub fraction_nt_identity
{
    my ( $npos, $nid ) = gjoseqlib::interpret_nt_align( @_[0,1] );
    ( $npos > 0 ) ? $nid / $npos : undef
}


#===============================================================================
#  The logic used here to optimize identification of "same" column depends
#  on the fact that only the second alignment ($y) has new columns, and they
#  are all gaps.  Therefore any non-gap character in alignment $y indicates
#  that it is not a column of added gaps (it must match).  After learning
#  that alignment $y has a gap, then we only need test $x for a gap.
#===============================================================================

sub same_col
{
    my ( $x, $colx, $y, $coly ) = @_;
    my ( $seq, $seqmax, $cy );

    $seqmax = @$x - 1;
    for ( $seq = 0; $seq <= $seqmax; $seq++ )
    {
        if ( substr($y->[$seq], $coly, 1) ne "-" ) { return 1 } # Non-gap in aligned
        if ( substr($x->[$seq], $colx, 1) ne "-" ) { return 0 } # Unmatched gap
    }
    return 1;
}


#===============================================================================
#  Trim sequences (needs to get updated to new tools and psiblast)
#===============================================================================
sub trim_with_blastall
{
    my( $clnseq, $clnali, $type ) = @_;

    my $tmpdir    = SeedAware::location_of_tmp( );
    my $blastfile = SeedAware::new_file_name( "$tmpdir/trim_blastdb" );
    my $seqfile   = SeedAware::new_file_name( "$tmpdir/trim_query" );

    gjoseqlib::print_alignment_as_fasta( $blastfile, scalar gjoseqlib::pack_sequences( $clnali ) );
    gjoseqlib::print_alignment_as_fasta( $seqfile,   scalar gjoseqlib::pack_sequences( $clnseq ) );

    $type = guess_seq_type( $clnseq->[2] ) if ! $type;
    my ( $is_prot, $prog, @opt ) = ( $type =~ m/^n/i ) ? qw( f blastn -r 1 -q -1 )
                                                       : qw( t blastp );
    my $formatdb = SeedAware::executable_for( 'formatdb' )
        or print STDERR "Could not locate executable file for 'formatdb'.\n"
            and return undef;

    my $blastall = SeedAware::executable_for( 'blastall' )
        or print STDERR "Could not locate executable file for 'blastall'.\n"
            and return undef;

    my @fmt_params = ( '-i', $blastfile, '-p', $is_prot );
    my $fmt_redirects = { stderr => '/dev/null' };
    SeedAware::system_with_redirect( $formatdb, @fmt_params, $fmt_redirects );

    my @params = ( '-p', $prog,
                   '-d', $blastfile,
                   '-i', $seqfile,
                   '-e',  0.001,
                   '-b',  5,        # Top 5 matches
                   '-v',  5,
                   '-F', 'f',
                   '-m',  8,
                   @opt
                 );
    my $redirects = { stderr => '/dev/null' };
    my $BLASTOUT = SeedAware::read_from_pipe_with_redirect( $blastall, @params, $redirects )
        or die "could not handle the blast";
    my @out = map { chomp; [ ( split )[ 1, 6, 7, 8, 9 ] ] } <$BLASTOUT>;
    close( $BLASTOUT );

    my @dbfile = map { "$blastfile.$_" } $type =~ m/^n/i ? qw( nin nhr nsq ) : qw( pin phr psq );
    unlink( $seqfile, $blastfile, @dbfile );

    if (@out < 1) { return undef }

    my %lenH;
    foreach my $tuple (@$clnali)
    {
        $lenH{$tuple->[0]} = $tuple->[2] =~ tr/a-zA-Z//;
    }

    @out = sort { ($a->[1] <=> $b->[1]) or ($a->[3] <=> $b->[3]) } @out;
    my @to_removeS = sort { $a <=> $b } map { &remove($_->[1],$_->[3])} @out;

    my $lenQ = length($clnseq->[2]);
    my @ends = map { [$lenQ - $_->[2], $lenH{$_->[0]} - $_->[4]] } @out;
    my @to_removeE = sort { $a <=> $b } map { &remove($_->[0]+1,$_->[1]+1) } @ends;
    my $trimmed_start = $to_removeS[0];
    my $trimmed_len = $lenQ - ($to_removeS[0] + $to_removeE[0]);
    my $seqT = substr($clnseq->[2],$trimmed_start,$trimmed_len);

    return ([$clnseq->[0],$clnseq->[1],$seqT],$trimmed_start,$trimmed_len);
}


sub remove
{
    my( $b1, $b2 ) = @_;
    return ($b2 <= 5) ? &max( $b1 - $b2, 0 ) : $b1 - 1;
}


#===============================================================================
#  Do a bootstrap sample of columns from an alignment:
#
#    \@alignment = bootstrap_sample( \@alignment );
#===============================================================================

sub bootstrap_sample
{
    my ( $align0, $seed ) = @_;
    return undef if ( ! $align0 ) || ( ref( $align0 ) ne 'ARRAY' ) || ( ! @$align0 );
    my $len = length( $align0->[0]->[2] );
    return $align0 if $len < 2;
    my @cols = map { int( $len * rand() ) } ( 1 .. $len );
    my @align1;
    foreach ( @$align0 )
    {
        my $seq1 = $_->[2];
        my $seq2 = $seq1;
        for ( my $i = 0; $i < $len; $i++ )
        {
            substr( $seq2, $i, 1 ) = substr( $seq1, $cols[$i], 1 );
        }
        push @align1, [ @$_[0,1], $seq2 ];
    }

    return wantarray ? @align1 : \@align1;
}


sub max { $_[0] > $_[1] ? $_[0] : $_[1] }


1;
