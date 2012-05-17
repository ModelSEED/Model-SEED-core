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

package gjoalign2html;

use strict;

#  Use FIGjs.pm if available:

my $have_FIGjs = eval { require FIGjs; 1 };

eval { use Data::Dumper };  # Not in all installations

#-------------------------------------------------------------------------------
#  Prepend and/or append unaligned sequence data to a trimmed alignment:
#
#       \@align = add_alignment_context( \@align, \@seqs, \%options )
#
#     ( \@align, $pre_len, $ali_len, $suf_len )
#               = add_alignment_context( \@align, \@seqs, \%options )
#
#  Options:
#
#     max_prefix => $limit  #  limit of residues to be added at beginning
#     max_suffix => $limit  #  limit of residues to be added at end
#     pad_char   => $char   #  character to pad beginning and end (D = ' ')
#
#-------------------------------------------------------------------------------
#  Change the pad character at the ends of an alignment:
#
#     \@align = repad_alignment( \@align, \%options )
#     \@align = repad_alignment(          \%options )
#      @align = repad_alignment( \@align, \%options )
#      @align = repad_alignment(          \%options )
#
#  Options:
#
#     pad_char => $char      #  character to pad beginning and end (D = ' ')
#     old_pad  => $regexp    #  characters to replace at end (D = [^A-Za-z.*])
#
#-------------------------------------------------------------------------------
#  Color an alignment by residue type
#
#       \@align             = color_alignment_by_residue( \@align, \%options )
#       \@align             = color_alignment_by_residue(          \%options )
#     ( \@align, \@legend ) = color_alignment_by_residue( \@align, \%options )
#     ( \@align, \@legend ) = color_alignment_by_residue(          \%options )
#
#  Options:
#
#      align     => \@alignment  #  alignment if not supplied as parameter
#      alignment => \@alignment  #  alignment if not supplied as parameter
#      colors    => \%colors     #  character colors (html spec.)
#      pallet    =>  $pallet     #  ale | gde | default
#      protein   =>  $bool       #  indicates a protein alignment
#
#-------------------------------------------------------------------------------
#  Color an alignment by consensus
#
#       \@align             = color_alignment_by_consensus( \@align, \%options )
#       \@align             = color_alignment_by_consensus(          \%options )
#     ( \@align, \%legend ) = color_alignment_by_consensus( \@align, \%options )
#     ( \@align, \%legend ) = color_alignment_by_consensus(          \%options )
#
#  Options:
#
#      align      => \@alignment   #  Alignment if not supplied as parameter
#      alignment  => \@alignment   #  Alignment if not supplied as parameter
#      colors     => \%colors      #  HTML colors for consensus categories
#      matrix     => \%scr_matrix  #  Hash of hashes of character align scores
#      max_f_diff =>  $max_f_diff  #  Maximum fraction exceptions to consensus
#      max_n_diff =>  $max_n_diff  #  Maximum number of exceptions to consensus
#      min_score  =>  $score       #  Score for conservative change (D=1)
#      protein    =>  $is_protein  #  Indicates a protein alignment
#
#-------------------------------------------------------------------------------
#  Make an html table with an alignment:
#
#       $html                = alignment_2_html_table( \@alignment, \%options )
#       $html                = alignment_2_html_table(              \%options )
#     ( $html, $javascript ) = alignment_2_html_table( \@alignment, \%options )
#     ( $html, $javascript ) = alignment_2_html_table(              \%options )
#
#  In scalar context, the routine returns a single block of html that includes
#  the JavaScript followed by the table.  In list context, they are returned
#  separately.
#
#  Options:
#
#     align        => \@alignment  #  Alignment, when not a parameter
#     alignment    => \@alignment  #  Alignment, when not a parameter
#     key          => \@legend     #  Append the supplied legend
#     legend       => \@legend     #  Append the supplied legend
#     nojavascript =>  $boolean    #  Omit the JavaScript for pop-ups
#     tooltip      =>  $boolean    #  Add pop-up tooltip to sequences
#     tooltip      => \%id2tip     #   (specify the tip for each id)
#
#  Each sequence can be a string, or an array of [ text, color ] pairs.
#  @legend is an array of lines of strings and/or [ text, color ] pairs.
#
#  Default tooltip is the id and description, but user can supply a
#  hash with arrays of alternative mouseover parameters:
#
#     mouseover( @{ $tooltip->{ $id } } )
#     mouseover( $ttl, $text, $menu, $parent, $ttl_color, $text_color )
#-------------------------------------------------------------------------------
#  Make an html page with an alignment:
#
#     $html = alignment_2_html_page( \@alignment, \%options )
#     $html = alignment_2_html_page(              \%options )
#
#  Options:
#
#     align     => \@alignment
#     alignment => \@alignment
#     key       => \@legend
#     legend    => \@legend
#     title     =>  $page_title
#
#  Each sequence can be a string, or an array of character-color pairs.
#-------------------------------------------------------------------------------
#
#  2009/08/25 -- Fix problem with wrap in the alignment.
#                Change all #abc to #aabbcc format due to a browser issue.
#
#-------------------------------------------------------------------------------

#  Some global defaults:

my $max_n_diff = 1;     # Maximum number of exceptions to consensus
my $max_f_diff = 0.10;  # Maximum fraction exceptions to consensus
my $minblos    = 1;     # Minimum score to be called a conservative change

#-------------------------------------------------------------------------------
#  Prepend and/or append unaligned sequence data to a trimmed alignment:
#
#       \@align                                 = add_alignment_context( \@align, \@seqs, \%options )
#     ( \@align, $pre_len, $ali_len, $suf_len ) = add_alignment_context( \@align, \@seqs, \%options )
#
#  Options:
#
#     max_prefix => $limit  #  limit of residues to be added at beginning
#     max_suffix => $limit  #  limit of residues to be added at end
#     pad_char   => $char   #  character to pad beginning and end (D = ' ')
#
#-------------------------------------------------------------------------------
sub add_alignment_context
{
    my ( $align, $seqs, $options ) = @_;

    $align && ( ref( $align ) eq 'ARRAY' )
        && ( @$align > 0 )
        or print STDERR "add_alignment_context called without valid alignment\n"
        and return undef;

    $seqs && ( ref( $seqs ) eq 'ARRAY' )
        && ( @$seqs > 0 )
        or print STDERR "add_alignment_context called without valid sequences\n"
        and return undef;

    my %index = map { $_->[0], $_ } @$seqs;

    my %options = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %options ) { $options{ canonical_key( $_ ) } = $options{ $_ } }

    my $max_prefix = defined( $options{ maxprefix } ) ? $options{ maxprefix } : 1e100;
    my $max_suffix = defined( $options{ maxsuffix } ) ? $options{ maxsuffix } : 1e100;
    my $pad_char   = $options{ padchar } ? substr( $options{ padchar }, 0, 1 ) : ' ';

    my $pre_len = 0;
    my $ali_len = length( $align->[0]->[2] );
    my $suf_len = 0;

    my %fix_data = ();
    my ( $id, $def, $aln_seq );
    my ( $pre0, $npre, $suf0, $nsuf );
    my ( $aligned, $full, $pos );

    foreach ( @$align )
    {
        ( $id, $def, $aln_seq ) = @$_;
        if ( $index{$id} )
        {
            $aligned = lc $aln_seq;
            $aligned =~ tr/a-z//cd;
            $full = lc $index{$id}->[2];
            $pos = index( $full, $aligned );
            if ( $pos > -1 )
            {
                $npre = ( $pos <= $max_prefix ) ? $pos : $max_prefix;
                $pre0 = $pos - $npre;
                if ( $npre > $pre_len ) { $pre_len = $npre }
                $suf0 = $pos + length( $aligned );
                $nsuf = length( $full ) - $suf0;
                $nsuf = $max_suffix if $nsuf > $max_suffix;
                if ( $nsuf > $suf_len ) { $suf_len = $nsuf }
            }
            else
            {
                $npre = 0;
                $nsuf = 0;
            }
        }
        $fix_data{ $id } = [ $pre0, $npre, $suf0, $nsuf, $index{$id} ];
    }

    my @align2;
    my ( @parts, $seq_entry );
    foreach ( @$align )
    {
        ( $id, $def, $aln_seq ) = @$_;
        ( $pre0, $npre, $suf0, $nsuf, $seq_entry ) = @{ $fix_data{ $id } };

        @parts = ();
        push @parts, $pad_char x ( $pre_len - $npre ) if ( $npre < $pre_len );
        push @parts, lc substr( $seq_entry->[2], $pre0, $npre ) if $npre;
        $aln_seq =~ s/^([^A-Za-z.]+)/$pad_char x length($1)/e if ( $pre_len && ! $npre );
        $aln_seq =~ s/([^A-Za-z.]+)$/$pad_char x length($1)/e if ( $suf_len && ! $nsuf );
        push @parts, uc $aln_seq;
        push @parts, lc substr( $seq_entry->[2], $suf0, $nsuf ) if $nsuf;
        push @parts, $pad_char x ( $suf_len - $nsuf ) if ( $nsuf < $suf_len );

        push @align2, [ $id, $def, join( '', @parts ) ];
    }

    wantarray ? ( \@align2, $pre_len, $ali_len, $suf_len ) : \@align2;
}


#-------------------------------------------------------------------------------
#  Change the pad character at the ends of an alignment:
#
#     \@align = repad_alignment( \@align, \%options )
#     \@align = repad_alignment(          \%options )
#      @align = repad_alignment( \@align, \%options )
#      @align = repad_alignment(          \%options )
#
#  Options:
#
#     pad_char => $char      #  character to pad beginning and end (D = ' ')
#     old_pad  => $regexp    #  characters to replace at end (D = [^A-Za-z.*])
#
#-------------------------------------------------------------------------------
sub repad_alignment
{
    my $align;
    $align = shift if ( ref($_[0]) eq 'ARRAY' );

    my %data = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %data ) { $data{ canonical_key( $_ ) } = $data{ $_ } }

    $align ||= $data{ align } || $data{ alignment };
    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) )
    {
        print STDERR "repad_alignment called without alignment\n";
        return ();
    }

    $data{ padchar } ||= $data{ pad };  #  Make this a fallback synonym;
    my $pad_char = $data{ padchar } ? substr( $data{ padchar }, 0, 1 ) : ' ';

    $data{ oldpad } ||= $data{ old };   #  Make this a fallback synonym;
    my $old_pad = $data{ oldpad  } ? $data{ padchar } : '[^A-Za-z.*]';
    my $reg1 = qr/^($old_pad+)/;
    my $reg2 = qr/($old_pad+)$/;

    my ( $id, $def, $seq );
    my @align2 = ();

    foreach ( @$align )
    {
        ( $id, $def, $seq ) = @$_;
        $seq =~ s/$reg1/$pad_char x length($1)/e;
        $seq =~ s/$reg2/$pad_char x length($1)/e;
        push @align2, [ $id, $def, $seq ];
    }

    wantarray ? @align2 : \@align2;
}


#-------------------------------------------------------------------------------
#  Color an alignment by residue type
#
#       \@align             = color_alignment_by_residue( \@align, \%options )
#       \@align             = color_alignment_by_residue(          \%options )
#     ( \@align, \@legend ) = color_alignment_by_residue( \@align, \%options )
#     ( \@align, \@legend ) = color_alignment_by_residue(          \%options )
#
#  Options:
#
#      align     => \@alignment  #  alignment if not supplied as parameter
#      alignment => \@alignment  #  alignment if not supplied as parameter
#      colors    => \%colors     #  character colors (html spec.)
#      pallet    =>  $pallet     #  ale | gde | default
#      protein   =>  $bool       #  indicates a protein alignment
#
#-------------------------------------------------------------------------------
sub color_alignment_by_residue
{
    my $align;
    $align = shift if ( ref($_[0]) eq 'ARRAY' );

    my %data = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %data ) { $data{ canonical_key( $_ ) } = $data{ $_ } }

    $align ||= $data{ align } || $data{ alignment };
    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) )
    {
        print STDERR "color_alignment_by_residue called without alignment\n";
        return ();
    }

    my $colors = $data{ color };
    if ( $colors && ( ref( $colors ) eq 'HASH' ) )
    {
        print STDERR "color_alignment_by_residue called without invalid colors hash\n";
        return ();
    }

    if ( ! $colors )
    {
        my $is_prot = defined( $data{ protein } ) ? $data{ protein } : &guess_prot( $align );
        my $pallet = $data{ pallet };
        $colors = $is_prot ? aa_colors( $pallet ) : nt_colors( $pallet );
    }

    my ( $id, $def, $seq );
    my $pad_char = $data{ padchar } || $data{ pad } || ' ';
    my $reg1 = qr/^([^A-Za-z.*]+)/;
    my $reg2 = qr/([^A-Za-z.*]+)$/;
    my @colored_align = ();

    foreach ( @$align )
    {
        ( $id, $def, $seq ) = @$_;
        $seq =~ s/$reg1/$pad_char x length($1)/e;
        $seq =~ s/$reg2/$pad_char x length($1)/e;
        push @colored_align, [ $id, $def, scalar color_sequence( $seq, $colors ) ];
    }

    my @legend = ();  #  Need to create this still
    if ( wantarray )
    {
        my ( $i, $chr );
        my @row = ();
        foreach ( $i = 32; $i < 127; $i++ )
        {
            $chr = chr( $i );
            push @row, [ $chr, $colors->{$chr} || '#ffffff' ];
            if ( $i % 32 == 31 ) { push @legend, [ @row ]; @row = () }
        }
        push @legend, [ @row ];
    }

    wantarray ? ( \@colored_align, \@legend ) : \@colored_align;
}


#-------------------------------------------------------------------------------
#  Convert sequence to list of character-color pairs:
#
#     \@colored_sequence = color_sequence( $sequence, \%colors )
#      @colored_sequence = color_sequence( $sequence, \%colors )
#-------------------------------------------------------------------------------
sub color_sequence
{
    my ( $seq, $colors ) = @_;
    my %colors = ref($colors) eq 'HASH' ? %$colors : ();
    my @colored_seq = map { [ $_, $colors{ $_ } || '#ffffff' ] } split //, $seq;
    wantarray ? @colored_seq : \@colored_seq;
}


#-------------------------------------------------------------------------------
#  Color an alignment by consensus
#
#       \@align             = color_alignment_by_consensus( \@align, \%options )
#       \@align             = color_alignment_by_consensus(          \%options )
#     ( \@align, \%legend ) = color_alignment_by_consensus( \@align, \%options )
#     ( \@align, \%legend ) = color_alignment_by_consensus(          \%options )
#
#  Options:
#
#      align      => \@alignment   #  Alignment if not supplied as parameter
#      alignment  => \@alignment   #  Alignment if not supplied as parameter
#      colors     => \%colors      #  HTML colors for consensus categories
#      matrix     => \%scr_matrix  #  Hash of hashes of character align scores
#      max_f_diff =>  $max_f_diff  #  Maximum fraction exceptions to consensus
#      max_n_diff =>  $max_n_diff  #  Maximum number of exceptions to consensus
#      min_score  =>  $score       #  Score for conservative change (D=1)
#      protein    =>  $is_protein  #  Indicates a protein alignment
#
#-------------------------------------------------------------------------------
sub color_alignment_by_consensus
{
    my $align;
    $align = shift if ( ref($_[0]) eq 'ARRAY' );

    #  Options, with canonical form of keys

    my %data = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %data ) { $data{ canonical_key( $_ ) } = $data{ $_ } }

    $align ||= $data{ align } || $data{ alignment };
    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) )
    {
        print STDERR "color_alignment_by_consensus called without alignment\n";
        return ();
    }

    my ( $pallet, $legend ) = consensus_pallet( $data{ color } );

    my $conserve_list = conservative_change_list( \%data );
    my $conserve_hash = conservative_change_hash( \%data );

    my $chars = qr/^[-*A-Za-z]$/;

    my $s;
    my $pad_char = $data{ padchar } || $data{ pad } || ' ';
    my $reg1 = qr/^([^A-Za-z.*]+)/;
    my $reg2 = qr/([^A-Za-z.*]+)$/;

    my @seq = map { $s = uc $_->[2];
                    $s =~ s/$reg1/$pad_char x length($1)/e;
                    $s =~ s/$reg2/$pad_char x length($1)/e;
                    $s
                  }
              @$align;

    #  Define the consensus type(s) for each site.  There are a 3 options:
    #    1. There is a single consensus nucleotide.
    #    2. Two residue types are sufficient to describe the position.
    #    3. A residue and conservative changes are sufficient.

    my $len = length( $seq[0] );

    $max_n_diff = $data{ maxndiff } if defined( $data{ maxndiff } );
    $max_f_diff = $data{ maxfdiff } if defined( $data{ maxfdiff } );

    my @col_clr;              #  An array of hashes, one for each column
    my $cons1 = ' ' x $len;   #  Primary consensus characters
    my $cons2 = ' ' x $len;   #  Secondary consensus characters

    my ( $i, %cnt, $chr, @c, $n_signif, $min_consen, $c1, $c2, $clr );

    for ( $i = 0; $i < $len; $i++)
    {
        #  Count the number of each residue type in the column

        %cnt = ();
        foreach ( @seq ) { $chr = substr($_,$i,1); $cnt{$chr}++ if $chr =~ /$chars/ }

        $n_signif = sum( map { $cnt{$_} } keys %cnt );
        $min_consen = $n_signif - max( $max_n_diff, int( $max_f_diff * $n_signif ) );

        ( $c1, $c2, @c ) = consensus_residues( \%cnt, $min_consen, $conserve_hash );

        substr( $cons1, $i, 1 ) = $c1 if $c1;
        substr( $cons2, $i, 1 ) = $c2 if $c2;
        push @col_clr, consensus_colors( $pallet, $conserve_list, $c1, $c2, @c );
    }

    my @color_align = ();
    my ( $id, $def, $seq );
    foreach ( @$align, [ 'Consen1', 'Primary consensus',   $cons1 ],
                       [ 'Consen2', 'Secondary consensus', $cons2 ]
            )
    {
        ( $id, $def, $seq ) = @$_;
        $seq =~ s/^([^A-Za-z.]+)/$pad_char x length($1)/e;
        $seq =~ s/([^A-Za-z.]+)$/$pad_char x length($1)/e;

        $i = 0;
        my @clr_seq = map { [ $_, $col_clr[$i++]->{$_} || '#ffffff' ] }
                      split //, $seq;
        push @color_align, [ $id, $def, \@clr_seq ];
    }

    wantarray ? ( \@color_align, $legend ) : \@color_align;
}


#-------------------------------------------------------------------------------
#  Work out the consensus residues at a site:
#
#     ( $consen1, $consen2, @chars ) = consensus_residues( $counts, $min_match,
#                                                          $conserve_hash )
#-------------------------------------------------------------------------------
sub consensus_residues
{
    my ( $cnt_hash, $min_match, $conserve_hash ) = @_;

    #  Sort the residues from most to least frequent, and note first 2:

    my %cnt = %$cnt_hash;
    my ( $c1, $c2, @c );

    ( $c1, $c2 ) = @c = sort { $cnt{$b} <=> $cnt{$a} } keys %cnt;
    ( $cnt{$c1} >= 2 ) or return ( '', '' );

    #  Are there at least $min_match of the most abundant?

    if ( $cnt{$c1} >= $min_match )
    {
        $c2  = '';
    }

    #  Are there at least $min_match of the two most abundant?

    elsif ( ( $cnt{$c2} >= 2 ) && ( ( $cnt{$c1} + $cnt{$c2} ) >= $min_match ) )
    {
        $c1 = lc $c1;
        $c2 = lc $c2;
    }

    #  Can we make a consensus of conservative changes?

    else
    {
        $c2 = '';
        my ( $is_conservative, @pos, $total );
        my $found = 0;
        foreach $c1 ( grep { /^[AC-IK-NP-TVWY]$/ } @c )
        {
            ( $is_conservative = $conserve_hash->{ $c1 } ) or next;
            @pos = grep { $is_conservative->{ $_ } } @c;
            $total = sum( map { $cnt{ $_ } } @pos );
            if ( $total >= $min_match ) { $found = 1; last }
        }
        $c1 = $found ? lc $c1 : '';
    }

    return ( $c1, $c2, @c );
}


#-------------------------------------------------------------------------------
#  Work out the residue colors for the consensus at a site:
#
#     \%color = consensus_colors( $pallet, $consevative, $cons1, $cons2, @chars )
#-------------------------------------------------------------------------------
sub consensus_colors
{
    my ( $pallet, $conservative, $c1, $c2, @c ) = @_;
#   print STDERR Dumper( $c1, $c2, \@c ); exit;
    return {} if ! $c1;

    my %pallet = ( ref($pallet) eq 'HASH' ) ? %$pallet
                                            : @{ scalar consensus_pallet() };

    $conservative = {} if ref( $conservative ) ne 'HASH';

    #  Mark everything but ' ' and . as mismatch, then overwrite exceptions:

    my %color = map  { $_ => $pallet{ mismatch } }
                grep { ! /^[ .]$/ }
                @c;

    if ( $c1 ne '-' )
    {
        $c1 = uc $c1;
        foreach ( @{ $conservative->{$c1} || [] } )
        {
            $color{ $_ } = $pallet{ positive }
        }
        $color{ $c1 } = $pallet{ consen1 };
        if ( $c2 )
        {
            $color{ uc $c2 } = ( $c2 ne '-' ) ? $pallet{ consen2 } : $pallet{ consen2g };
        }
    }
    else
    {
        $color{ $c1 } = $pallet{ consen1g };
        if ( $c2 ) { $color{ uc $c2 } = $pallet{ consen2 } }
    }

    #  Copy colors to lowercase letters:

    foreach ( grep { /^[A-Z]$/ } keys %color )
    {
        $color{ lc $_ } = $color{ $_ }
    }

    return \%color;
}


#-------------------------------------------------------------------------------
#  Numerical maximum:
#
#     $max = max( $a, $b )
#-------------------------------------------------------------------------------
sub max { $_[0] > $_[1] ? $_[0] : $_[1] }


#-------------------------------------------------------------------------------
#  Define the colors used to color by consensus:
#
#       \%color_pallet             = consensus_pallet()
#       \%color_pallet             = consensus_pallet( \%user_pallet )
#     ( \%color_pallet, \@legend ) = consensus_pallet()
#     ( \%color_pallet, \@legend ) = consensus_pallet( \%user_pallet )
#
#       \%color_pallet is key/color pairs, where key is a residue category
#       \@legend is lines of text/color pairs
#-------------------------------------------------------------------------------
sub consensus_pallet
{
    #  Initialize with a standard set, ensuring that all keys are covered:

    my %pallet = ( ''       => '#ffffff',
                   other    => '#ffffff',
                   consen1  => '#bbddff', consen1g => '#ddeeff',
                   positive => '#66ee99',
                   consen2  => '#eeee44', consen2g => '#eeeeaa',
                   mismatch => '#ff99ff'
                 );

    #  Overwrite defaults with user-supplied colors

    if ( ref($_[0]) eq 'HASH' )
    {
        my %user_pallet = %{ $_[0] };
        foreach ( keys %user_pallet ) { $pallet{ $_ } = $user_pallet{ $_ } }
    }

    my @legend;
    if ( wantarray )
    {
        @legend = ( [ [ 'Consensus 1'             => $pallet{ consen1  } ],
                      [ ' (when a gap)'           => $pallet{ consen1g } ] ],

                    [ [ 'Conservative difference' => $pallet{ positive } ] ],

                    [ [ 'Consensus 2'             => $pallet{ consen2  } ],
                      [ ' (when a gap)'           => $pallet{ consen2g } ] ],

                    [ [ 'Nonconservative diff.'   => $pallet{ mismatch } ] ],

                    [ [ 'Other character'         => $pallet{ ''       } ] ],
                  );
    }

    wantarray ? ( \%pallet, \@legend ) : \%pallet;
}


#-------------------------------------------------------------------------------
#  Define the list of conserved amino acid replacements for each amino acid:
#
#     \%conserve_change_lists = conservative_change_list( \%options )
#     \%conserve_change_lists = conservative_change_list(  %options )
#
#     \@conserve_changes = $conserve_change_lists->{ $aa };
#
#  Options:
#
#     min_score =>  $score       #  Minimum score for conservative designation
#     matrix    => \%score_hash  #  Score matrix as hash of hashes
#-------------------------------------------------------------------------------
sub conservative_change_list
{
    my %options = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %options ) { $options{ canonical_key( $_ ) } = $options{ $_ } }

    my $min_score = defined( $options{ minscore } ) ? $options{ minscore } : 1;

    my $matrix = ( ref( $options{ matrix } ) eq 'HASH' ) ? $options{ matrix }
                                                         : blosum62_hash_hash();

    my %hash;
    foreach ( keys %$matrix )
    {
        my $score = $matrix->{ $_ };
        $hash{ $_ } = [ grep { $score->{ $_ } >= $min_score } keys %$score ];
    }
    return \%hash;
}


#-------------------------------------------------------------------------------
#  Define a hash of conserved amino acid replacements for each amino acid:
#
#     \%conserve_change_hashes = conservative_change_hash( \%options )
#     \%conserve_change_hashes = conservative_change_hash(  %options )
#
#     \%conserve_changes = $conserve_change_hashes->{ $aa };
#
#  Options:
#
#     min_score =>  $score       #  Minimum score for conservative designation
#     matrix    => \%score_hash  #  Score matrix as hash of hashes
#-------------------------------------------------------------------------------
sub conservative_change_hash
{
    my %options = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %options ) { $options{ canonical_key( $_ ) } = $options{ $_ } }

    my $min_score = defined( $options{ minscore } ) ? $options{ minscore } : 1;

    my $matrix = ( ref( $options{ matrix } ) eq 'HASH' ) ? $options{ matrix }
                                                         : blosum62_hash_hash();

    my %hash;
    foreach ( keys %$matrix )
    {
        my $score = $matrix->{ $_ };
        $hash{ $_ } = { map  { $_ => 1 }
                        grep { $score->{ $_ } >= $min_score }
                        keys %$score
                      };
    }

    return \%hash;
}


#-------------------------------------------------------------------------------
#  Define a hash of hashes with the blosum62 scores for each amino acid:
#
#     \%blosum62 = blosum62_hash_hash()
#      $score    = $blosum62->{$aa1}->{$aa2};
#
#-------------------------------------------------------------------------------
sub blosum62_hash_hash
{
    my ( $aa_list, $raw_scores ) = raw_blosum62();
    my %hash;
    my @scores = @$raw_scores;
    foreach ( @$aa_list )
    {
        my @scr = @{ shift @scores };
        $hash{ $_ } = { map { $_ => shift @scr } @$aa_list };
    }
    return \%hash;
}


#-------------------------------------------------------------------------------
#  Define an ordered list of aminoacids and lists of each of their blosum scores
#
#     ( \@aa_list, \@scores ) = raw_blosum62()
#
#-------------------------------------------------------------------------------
sub raw_blosum62
{
    return ( [ qw( A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  * ) ],
             [ map { shift @$_; $_ }
               (
                 #        A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *   #
                 [ qw( A  4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1  0 -4 ) ],
                 [ qw( R -1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4 ) ],
                 [ qw( N -2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4 ) ],
                 [ qw( D -2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4 ) ],
                 [ qw( C  0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -2 -4 ) ],
                 [ qw( Q -1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4 ) ],
                 [ qw( E -1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4 ) ],
                 [ qw( G  0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4 ) ],
                 [ qw( H -2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4 ) ],
                 [ qw( I -1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4 ) ],
                 [ qw( L -1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4 ) ],
                 [ qw( K -1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4 ) ],
                 [ qw( M -1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4 ) ],
                 [ qw( F -2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4 ) ],
                 [ qw( P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -2 -4 ) ],
                 [ qw( S  1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0  0 -4 ) ],
                 [ qw( T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1  0 -4 ) ],
                 [ qw( W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -2 -4 ) ],
                 [ qw( Y -2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4 ) ],
                 [ qw( V  0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4 ) ],
                 [ qw( B -2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4 ) ],
                 [ qw( Z -1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4 ) ],
                 [ qw( X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -2  0  0 -2 -1 -1 -1 -1 -1 -4 ) ],
                 [ qw( * -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1 ) ]
               )
             ]
           )
}


#-------------------------------------------------------------------------------
#  Make an html table with an alignment:
#
#       $html                = alignment_2_html_table( \@alignment, \%options )
#       $html                = alignment_2_html_table(              \%options )
#     ( $html, $javascript ) = alignment_2_html_table( \@alignment, \%options )
#     ( $html, $javascript ) = alignment_2_html_table(              \%options )
#
#  In scalar context, the routine returns a single block of html that includes
#  the JavaScript followed by the table.  In list context, they are returned
#  separately.
#
#  Options:
#
#     align        => \@alignment  #  Alignment, when not a parameter
#     alignment    => \@alignment  #  Alignment, when not a parameter
#     key          => \@legend     #  Append the supplied legend
#     legend       => \@legend     #  Append the supplied legend
#     nojavascript =>  $boolean    #  Omit the JavaScript for pop-ups
#     tooltip      =>  $boolean    #  Add pop-up tooltip to sequences
#     tooltip      => \%id2tip     #   (specify the tip for each id)
#
#  Each sequence can be a string, or an array of [ text, color ] pairs.
#  @legend is an array of lines of strings and/or [ text, color ] pairs.
#
#  Default tooltip is the id and description, but user can supply a
#  hash with arrays of alternative mouseover parameters:
#
#     mouseover( @{ $tooltip->{ $id } } )
#     mouseover( $ttl, $text, $menu, $parent, $ttl_color, $text_color )
#-------------------------------------------------------------------------------
sub alignment_2_html_table
{
    my $align;
    $align = shift if ( ref($_[0]) eq 'ARRAY' );

    #  Options, with canonical form of keys

    my %options = ( ref( $_[0] ) eq 'HASH' ) ? %{ $_[0] } : @_;
    foreach ( keys %options ) { $options{ canonical_key( $_ ) } = $options{ $_ } }

    $align ||= $options{ align } || $options{ alignment };
    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) )
    {
        print STDERR "alignment_2_html_table called without alignment\n";
        return '';
    }

    my $tooltip = $options{ tooltip } || $options{ popup } || 0;
    my $tiplink = '';

    my $nojavascript = $options{ nojavascript } || ( $tooltip ? 0 : 1 );

    my @html;
    push @html, "<TABLE Col=5 CellPadding=0 CellSpacing=0>\n";
    foreach ( @$align )
    {
        if ( $tooltip )
        {
            #  Default tooltip is the id and description, but user can supply a
            #  hash with alternative mouseover parameters:
            #
            #     mouseover( $ttl, $text, $menu, $parent, $ttl_color, $text_color )
            #
            my @args;
            if ( ( ref( $tooltip ) eq 'HASH' )
              && ( ref( $tooltip->{ $_->[0] } ) eq 'ARRAY' )
               )
            {
                @args = @{ $tooltip->{ $_->[0] } }
            }
            else
            {
                @args = ( $_->[0], ( $_->[1] || ' ' ) );
            }
            $tiplink = '<A' . &mouseover( @args ) . '>';
        }

        push @html, "  <TR>\n",
                    "    <TD NoWrap>$_->[0]</TD>\n",
                    "    <TD NoWrap>&nbsp;</TD>\n",  # Getting rid of padding, so ...
                    "    <TD NoWrap>$_->[1]</TD>\n",
                    "    <TD NoWrap>&nbsp;</TD>\n",  # Getting rid of padding, so ...
                    "    <TD NoWrap>&nbsp;</TD>\n",
                    "    <TD NoWrap><TT><Big>",      # Switch from <PRE> to <TT> requires nowrap -- 2009/08/25
                             ( $tooltip ? $tiplink : () ),
                             sequence_2_html( $_->[2] ),
                             ( $tooltip ? '</A>' : () ),
                             "</Big></TT></TD>\n",
                    "  </TR>\n";
    }
    push @html, "</TABLE>\n";

    my $legend = $options{ key } || $options{ legend };
    if ( ref( $legend ) eq 'ARRAY' )
    {
        push @html, "<BR />\n", "<TABLE Col=1 CellPadding=0 CellSpacing=0>\n";
        foreach ( @$legend )
        {
            push @html, "  <TR><TD><TT><Big>",
                           sequence_2_html( $_ ),
                           "</Big></TT></TD></TR>\n";
        }
        push @html, "</TABLE>\n";
    }

    my $javascript = $nojavascript ? '' : &mouseover_JavaScript();

    wantarray && $javascript ? ( join( '', @html ), $javascript )  #  ( $html, $script )
                             :   join( '', $javascript, @html );   #    $html
}


#-------------------------------------------------------------------------------
#  Make html to display a possibly colored sequence:
#
#     $html = sequence_2_html(  $string )
#     $html = sequence_2_html( \@character_color_pairs )
#
#  Each sequence can be a string, or an array of character-color pairs.
#-------------------------------------------------------------------------------
sub sequence_2_html
{
    return $_[0] if ref( $_[0] ) ne 'ARRAY';

    my $string = shift;
    my @html = ();
    my ( $txt, $clr );
    foreach ( @{ merge_common_color( $string ) } )
    {
        $txt = html_esc( $_->[0] );
        $txt or next;
        $txt =~ s/ /&nbsp;/g; # 2009-03-02 -- Change from <Pre> to <TT> wrapper
        $clr = $_->[1];
        push @html, ( $clr ? qq(<span style="background-color:$clr">$txt</span>)
                           : $txt
                    )
    }
    join '', @html;
}


#-------------------------------------------------------------------------------
#  Merge adjacent strings with same color to cut amount of html:
#
#     \@character_color_pairs = merge_common_color( \@character_color_pairs )
#
#-------------------------------------------------------------------------------
sub merge_common_color
{
    return $_[0] if ref( $_[0] ) ne 'ARRAY';

    my @string = ();
    my $color  = '';
    my @common_color = ();
    foreach ( @{ $_[0] }, [ '', 0 ] )  # One bogus empty string to flush it
    {
        if ( $_->[1] ne $color )
        {
            push @string, [ join( '', @common_color ), $color ],
            @common_color = ();
            $color = $_->[1]
        }
        push @common_color, $_->[0];
    }
    return \@string;
}


#-------------------------------------------------------------------------------
#  Make an html page with an alignment:
#
#     $html = alignment_2_html_page( \@alignment, \%options )
#     $html = alignment_2_html_page(              \%options )
#
#  Options:
#
#     align     => \@alignment
#     alignment => \@alignment
#     key       => \@legend
#     legend    => \@legend
#     title     =>  $page_title
#
#  Each sequence can be a string, or an array of character-color pairs.
#-------------------------------------------------------------------------------
sub alignment_2_html_page
{
    my $options = ref( $_[0] ) eq 'HASH' ? $_[0] :
                  ref( $_[1] ) eq 'HASH' ? $_[1] : {};

    join '', html_prefix( $options ),
             ( alignment_2_html_table( @_ ) )[1,0],
             html_suffix( $options );
}


#-------------------------------------------------------------------------------
#  $html_page_start = html_prefix()
#-------------------------------------------------------------------------------
sub html_prefix
{
    my $options = ref( $_[0] ) eq 'HASH' ? $_[0] : {};

    my $title = $options->{ title } || 'Alignment';

    return <<"End_of_Prefix";
<HTML>
<HEAD>
<TITLE>$title</TITLE>
</HEAD>
<BODY>
End_of_Prefix
}


#-------------------------------------------------------------------------------
#  $html_page_end = html_suffix()
#-------------------------------------------------------------------------------
sub html_suffix
{
    return <<"End_of_Suffix";
</BODY>
</HTML>
End_of_Suffix
}


#-------------------------------------------------------------------------------
#  $html_text = html_esc{ $text )
#-------------------------------------------------------------------------------
sub html_esc
{
    my $txt = shift;
    $txt =~ s/\&/&amp;/g;
    $txt =~ s/\</&lt;/g;
    $txt =~ s/\>/&gt;/g;
    return $txt;
}


sub sum
{
    my $cnt = 0;
    while ( defined( $_[0] ) ) { $cnt += shift }
    $cnt
}


#-------------------------------------------------------------------------------
#  A canonical key is lower case, has no underscores, and no terminal s
#
#     $key = canonical_key( $key )
#-------------------------------------------------------------------------------
sub canonical_key { my $key = lc shift; $key =~ s/_//g; $key =~ s/s$//; $key }


#-------------------------------------------------------------------------------
#  $is_protein_alignment = guess_prot( \@alignment )
#-------------------------------------------------------------------------------
sub guess_prot
{
    my $align = shift;
    my $seq = uc $align->[0]->[-1];               # First sequence
    my $nt  = $seq =~ tr/ACGTU//;                 # Nucleotides
    my $res = $seq =~ tr/ACDEFGHIKLMNPQRSTUVWY//; # Total residues
    return ( $nt > 0.7 * $res ) ? 0 : 1;          # >70% of total?
}



#-------------------------------------------------------------------------------
#  \%character_color_pallet = aa_colors()             #  Default
#  \%character_color_pallet = aa_colors( $set_name )  #  ale
#-------------------------------------------------------------------------------
sub aa_colors
{
    my $pallet = shift || '';
    my %colors;

    if ( $pallet =~ /ale/i )
    {
        %colors = (
            ' ' => '#bebebe',  # Grey
            '~' => '#bebebe',  # Grey
            '-' => '#696969',  # DimGray
            '.' => '#828282',  # Grey51
            '*' => '#ff0000',  # Red

             G  => '#ffffff',  # White

             A  => '#d3d3d3',  # LightGray
             V  => '#d3d3d3',  # LightGray
             L  => '#d3d3d3',  # LightGray
             I  => '#d3d3d3',  # LightGray
             M  => '#d3d3d3',  # LightGray
             C  => '#d3d3d3',  # LightGray
             U  => '#d3d3d3',  # LightGray

             W  => '#ffd700',  # Gold
             F  => '#ffd700',  # Gold
             Y  => '#ffd700',  # Gold

             K  => '#00bfff',  # DeepSkyBlue
             R  => '#00bfff',  # DeepSkyBlue
             H  => '#40e0d0',  # Turquoise

             N  => '#98fb98',  # PaleGreen
             Q  => '#98fb98',  # PaleGreen
             S  => '#98fb98',  # PaleGreen
             T  => '#98fb98',  # PaleGreen
             P  => '#98fb98',  # PaleGreen

             D  => '#fa8072',  # Salmon
             E  => '#fa8072',  # Salmon
             );
    }
    else
    {
        %colors = (
            ' ' => '#ffffff',  # White
            '~' => '#ffffff',  # White
            '.' => '#ffffff',  # White
            '-' => '#888888',  # Gray
            '*' => '#ff0000',  # Red

             G  => '#dd88dd',  # DullMagenta

             A  => '#dddddd',  # LightGray
             V  => '#dddddd',  # LightGray
             L  => '#dddddd',  # LightGray
             I  => '#dddddd',  # LightGray
             M  => '#dddddd',  # LightGray

             C  => '#ffff00',  # Yellow
             U  => '#ffff00',  # Yellow

             W  => '#ddaa22',  # Goldenrod
             F  => '#ddaa22',  # Goldenrod
             Y  => '#ddaa22',  # Goldenrod

             K  => '#00bbff',  # DeepSkyBlue
             R  => '#00bbff',  # DeepSkyBlue
             H  => '#44eedd',  # Turquoise

             N  => '#99ff99',  # PaleGreen
             Q  => '#99ff99',  # PaleGreen
             S  => '#99ff99',  # PaleGreen
             T  => '#99ff99',  # PaleGreen

             P  => '#aaddaa',  # DullGreen

             D  => '#ff8877',  # Salmon
             E  => '#ff8877',  # Salmon
             );
    }

    foreach ( keys %colors ) { $colors{ lc $_ } = $colors{ $_ } }

    return \%colors;
}


#-------------------------------------------------------------------------------
#  \%character_color_pallet = nt_colors()             #  Default
#  \%character_color_pallet = nt_colors( $set_name )  #  ale | gde
#-------------------------------------------------------------------------------
sub nt_colors
{
    my $pallet = shift || '';
    my %colors;

    if ( $pallet =~ /ale/i )
    {
        %colors = (
            ' ' => '#666666',  # DimGray
            '~' => '#666666',  # DimGray
            '-' => '#bbbbbb',  # Gray
            '.' => '#888888',  # Gray51

             A  => '#ffdd00',  # Gold
             C  => '#00ffff',  # Cyan
             G  => '#ffff00',  # Yellow
             T  => '#99ff99',  # PaleGreen
             U  => '#99ff99',  # PaleGreen
             );
    }
    elsif ( $pallet =~ /gde/i )
    {
        %colors = (
            ' ' => '#666666',  # DimGray
            '~' => '#666666',  # DimGray
            '-' => '#bbbbbb',  # Gray
            '.' => '#888888',  # Gray51

             A  => '#ff0000',  # Red
             C  => '#0000ff',  # Blue
             G  => '#ffff88',  # PaleYellow
             T  => '#00ff00',  # Green
             U  => '#00ff00',  # Green
             );
    }
    else
    {
        %colors = (
            ' ' => '#777777',
            '~' => '#777777',
            '-' => '#bbbbbb',
            '.' => '#888888',

             A  => '#ff6666',
             G  => '#ffff00',
             C  => '#00ff00',
             T  => '#8888ff',
             U  => '#8888ff',

             R  => '#ffaa44',
             Y  => '#44dd88',
             K  => '#bbbb99',
             M  => '#eeee66',
             S  => '#aaff55',
             W  => '#cc88cc',

             B  => '#bbdddd',
             H  => '#bbbbdd',
             D  => '#ddbbdd',
             V  => '#ddddaa',

             N  => '#dddddd',
             );
    }

    foreach ( keys %colors ) { $colors{ lc $_ } = $colors{ $_ } }

    return \%colors;
}


#-------------------------------------------------------------------------------
#  Return a string for adding an onMouseover tooltip handler:
#
#     mouseover( $title, $text, $menu, $parent, $titlecolor, $bodycolor)
#
#  The code here is virtually identical to that in FIGjs.pm, but makes this
#  SEED independent.
#-------------------------------------------------------------------------------
sub mouseover
{
    if ( $have_FIGjs ) { return &FIGjs::mouseover( @_ ) }

    my ( $title, $text, $menu, $parent, $titlecolor, $bodycolor ) = @_;

    defined( $title ) or $title = '';
    $title =~ s/'/\\'/g;    # escape '
    $title =~ s/"/&quot;/g; # escape "

    defined( $text ) or $text = '';
    $text =~ s/'/\\'/g;    # escape '
    $text =~ s/"/&quot;/g; # escape "

    defined( $menu ) or $menu = '';
    $menu =~ s/'/\\'/g;    # escape '
    $menu =~ s/"/&quot;/g; # escape "

    $parent     = '' if ! defined $parent;
    $titlecolor = '' if ! defined $titlecolor;
    $bodycolor  = '' if ! defined $bodycolor;

    qq( onMouseover="javascript:if(!this.tooltip) this.tooltip=new Popup_Tooltip(this,'$title','$text','$menu','$parent','$titlecolor','$bodycolor');this.tooltip.addHandler(); return false;" );
}


#-------------------------------------------------------------------------------
#  Return a text string with the necessary JavaScript for the mouseover
#  tooltips.
#
#     $html = mouseover_JavaScript()
#
#  The code here is virtually identical to that in FIGjs.pm, but makes this
#  SEED independent.
#-------------------------------------------------------------------------------
sub mouseover_JavaScript
{
    if ( $have_FIGjs ) { return &FIGjs::toolTipScript( ) }

    return <<'End_of_JavaScript';
<SCRIPT Language='JavaScript'>
//
//  javascript class for tooltips and popup menus
//
//  This class manages the information, creating area to draw tooltips and
//  popup menus and provides the event handlers to handle them
//
var DIV_WIDTH=250;
var px;     // position suffix with "px" in some cases
var initialized = false;
var ns4 = false;
var ie4 = false;
var ie5 = false;
var kon = false;
var iemac = false;
var tooltip_name='popup_tooltip_div';

function Popup_Tooltip(object, tooltip_title, tooltip_text,
                       popup_menu, use_parent_pos, head_color,
                       body_color) {
    // The first time an object of this class is instantiated,
    // we have to setup some browser specific settings

    if (!initialized) {
         ns4 = (document.layers) ? true : false;
         ie4 = (document.all) ? true : false;
         ie5 = ((ie4) && ((navigator.userAgent.indexOf('MSIE 5') > 0) ||
                (navigator.userAgent.indexOf('MSIE 6') > 0))) ? true : false;
         kon = (navigator.userAgent.indexOf('konqueror') > 0) ? true : false;
         if(ns4||kon) {
             //setTimeout("window.onresize = function () {window.location.reload();};", 2000);
         }
         ns4 ? px="" : px="px";
         iemac = ((ie4 || ie5) && (navigator.userAgent.indexOf('Mac') > 0)) ? true : false;

         initialized=true;
    }

    if (iemac) { return; } // Give up

    this.tooltip_title = tooltip_title;
    this.tooltip_text  = tooltip_text;

    if (head_color) { this.head_color = head_color; }
    else            { this.head_color = "#333399";  }

    if (body_color) { this.body_color = body_color; }
    else            { this.body_color = "#CCCCFF";  }

    this.popup_menu = popup_menu;
    if (use_parent_pos) {
        this.popup_menu_x = object.offsetLeft;
        this.popup_menu_y = object.offsetTop + object.offsetHeight + 3;
    }
    else {
        this.popup_menu_x = -1;
        this.popup_menu_y = -1;
    }

    // create the div if necessary
    // the div may be shared between several instances
    // of this class

    this.div = getDiv(tooltip_name);
    if (! this.div) {
        // create a hidden div to contain the information
        this.div = document.createElement("div");
        this.div.id=tooltip_name;
        this.div.style.position="absolute";
        this.div.style.zIndex=0;
        this.div.style.top="0"+px;
        this.div.style.left="0"+px;
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.tooltip_visible=0;
        this.div.menu_visible=0
        document.body.appendChild(this.div);
    }

    // register methods

    this.showTip = showTip;
    this.hideTip = hideTip;
    this.fillTip = fillTip;
    this.showMenu = showMenu;
    this.hideMenu = hideMenu;
    this.fillMenu = fillMenu;
    this.addHandler = addHandler;
    this.delHandler = delHandler;
    this.mousemove = mousemove;
    this.showDiv = showDiv;

    // object state

    this.attached = object;
    object.tooltip = this;
}

function getDiv() {
    if      (ie5 || ie4)      { return document.all[tooltip_name]; }
    else if (document.layers) { return document.layers[tooltip_name]; }
    else if (document.all)    { return document.all[tooltip_name]; }
                                return document.getElementById(tooltip_name);
}

function hideTip() {
    if (this.div.tooltip_visible) {
        this.div.innerHTML="";
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.tooltip_visible=0;
    }
}

function hideMenu() {
    if (this.div && this.div.menu_visible) {
        this.div.innerHTML="";
        this.div.style.visibility=ns4?"hide":"hidden";
        this.div.menu_visible=0;
    }
}

function fillTip() {
    this.hideTip();
    this.hideMenu();
    if (this.tooltip_title && this.tooltip_text) {
        this.div.innerHTML='<table width='+DIV_WIDTH+' border=0 cellpadding=2 cellspacing=0 bgcolor="'+this.head_color+'"><tr><td class="tiptd"><table width="100%" border=0 cellpadding=0 cellspacing=0><tr><th><span class="ptt"><b><font color="#FFFFFF">'+this.tooltip_title+'</font></b></span></th></tr></table><table width="100%" border=0 cellpadding=2 cellspacing=0 bgcolor="'+this.body_color+'"><tr><td><span class="pst"><font color="#000000">'+this.tooltip_text+'</font></span></td></tr></table></td></tr></table>';
        this.div.tooltip_visible=1;
    }
}

function fillMenu() {
    this.hideTip();
    this.hideMenu();
    if (this.popup_menu) {
        this.div.innerHTML='<table cellspacing="2" cellpadding="1" bgcolor="#000000"><tr bgcolor="#eeeeee"><td><div style="max-height:300px;min-width:100px;overflow:auto;">'+this.popup_menu+'</div></td></tr></table>';
        this.div.menu_visible=1;
    }
}

function showDiv(x,y) {
    winW=(window.innerWidth)? window.innerWidth+window.pageXOffset-16 :
        document.body.offsetWidth-20;
    winH=(window.innerHeight)?window.innerHeight+window.pageYOffset :
        document.body.offsetHeight;
    if (window.getComputedStyle) {
        current_style = window.getComputedStyle(this.div,null);
        div_width = parseInt(current_style.width);
        div_height = parseInt(current_style.height);
    }
    else {
        div_width = this.div.offsetWidth;
        div_height = this.div.offsetHeight;
    }
    this.div.style.left=(((x + div_width) > winW) ? winW - div_width : x) + px;
    this.div.style.top=(((y + div_height) > winH) ? winH - div_height: y) + px;
//    this.div.style.color = "#eeeeee";
    this.div.style.visibility=ns4?"show":"visible";
}

function showTip(e,y) {
    if (!this.div.menu_visible) {
        if (!this.div.tooltip_visible) {
            this.fillTip();
        }
        var x;
        if (typeof(e) == 'number') {
            x = e;
        }
        else {
            x=e.pageX?e.pageX:e.clientX?e.clientX:0;
            y=e.pageY?e.pageY:e.clientY?e.clientY:0;
        }
        x+=2; y+=2;
        this.showDiv(x,y);
        this.div.tooltip_visible=1;
    }
}

function showMenu(e) {
    if (this.div) {
        if (!this.div.menu_visible) {
            this.fillMenu();
        }
        var x;
        var y;

        // if the menu position was given as parameter
        // to the constructor, then use that position
        // or fall back to mouse position

        if (this.popup_menu_x != -1) {
            x = this.popup_menu_x;
            y = this.popup_menu_y;
        }
        else {
            x = e.pageX ? e.pageX : e.clientX ? e.clientX : 0;
            y = e.pageY ? e.pageY : e.clientY ? e.clientY : 0;
        }
        this.showDiv(x,y);
        this.div.menu_visible=1;
    }
}

//  Add the event handler to the parent object.
//  The tooltip is managed by the mouseover and mouseout
//  events. mousemove is captured, too

function addHandler() {
    if (iemac) { return; }  // ignore Ie on mac

    if(this.tooltip_text) {
        this.fillTip();
        this.attached.onmouseover = function (e) {
            this.tooltip.showTip(e);
            return false;
        };
        this.attached.onmousemove = function (e) {
            this.tooltip.mousemove(e);
            return false;
        };
    }

    if (this.popup_menu) {
        this.attached.onclick = function (e) {
                   this.tooltip.showMenu(e);

                   // reset event handlers
                   if (this.tooltip_text) {
                       this.onmousemove=null;
                       this.onmouseover=null;
                       this.onclick=null;
                   }

                   // there are two mouseout events,
                   // one when the mouse enters the inner region
                   // of our div, and one when the mouse leaves the
                   // div. we need to handle both of them
                   // since the div itself got no physical region on
                   // the screen, we need to catch event for its
                   // child elements
                   this.tooltip.div.moved_in=0;
                   this.tooltip.div.onmouseout=function (e) {
                       var div = getDiv(tooltip_name);
                       if (e.target.parentNode == div) {
                           if (div.moved_in) {
                               div.menu_visible = 0;
                               div.innerHTML="";
                               div.style.visibility=ns4?"hide":"hidden";
                           }
                           else {
                               div.moved_in=1;
                           }
                           return true;
                       };
                       return true;
                   };
                   this.tooltip.div.onclick=function() {
                       this.menu_visible = 0;
                       this.innerHTML="";
                       this.style.visibility=ns4?"hide":"hidden";
                       return true;
                   }
                   return false; // do not follow existing links if a menu was defined!

        };
    }
    this.attached.onmouseout = function () {
                                   this.tooltip.delHandler();
                                   return false;
                               };
}

function delHandler() {
    if (this.div.menu_visible) { return true; }

    // clean up

    if (this.popup_menu) { this.attached.onmousedown = null; }
    this.hideMenu();
    this.hideTip();
    this.attached.onmousemove = null;
    this.attached.onmouseout = null;

    // re-register the handler for mouse over

    this.attached.onmouseover = function (e) {
                                    this.tooltip.addHandler(e);
                                    return true;
                                };
    return false;
}

function mousemove(e) {
    if (this.div.tooltip_visible) {
        if (e) {
            x=e.pageX?e.pageX:e.clientX?e.clientX:0;
            y=e.pageY?e.pageY:e.clientY?e.clientY:0;
        }
        else if (event) {
            x=event.clientX;
            y=event.clientY;
        }
        else {
            x=0; y=0;
        }

        if(document.documentElement) // Workaround for scroll offset of IE
        {
            x+=document.documentElement.scrollLeft;
            y+=document.documentElement.scrollTop;
        }
        this.showTip(x,y);
    }
}

function setValue(id , val) {
   var element = document.getElementById(id);
   element.value = val;
}

</SCRIPT>
End_of_JavaScript
}


1;
