
#
# This is a SAS component
#

#
# Copyright (c) 2003-2007 University of Chicago and Fellowship
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

package find_special_proteins;

use strict;
use gjoseqlib;
use gjoparseblast;
use NCBI_genetic_code;

# use Data::Dumper;

#===============================================================================
#  Use a database of reference sequences to locate selenoproteins in a genome.
#  This program will not (by design) find new instances of selenocysteine.
#  With the pyrrolysine option, find pyrrolysyl proteins.
#
#      @locs = find_selenoproteins( \%params )
#
#  Required parameters:
#
#      contigs     => \@contigs             # genome is a synonym
#
#  Optional paramaters:
#
#      allow_C     =>  1                    # allow C in reference to align with SeC (D = 0)
#      allow_K     =>  1                    # allow K in reference to align with PyK (D = 0)
#      comment     =>  $text                # comment for output hash
#      is_init     => \@initiator_codons           # D = [ATG,GTG]
#      is_alt      => \@second_choice_init_codons  # D = [TTG]
#      is_term     => \@terminator_codons          # D = [TAA,TAG,TGA]
#      note        =>  $text                # same as 'comment'
#      pyrrolysine =>  1                    # find pyrrolysylproteins
#      references  => \@selenoproteins      # selenocysteine must be U or X
#      references  => \@pyrrolysylproteins  # pyrrolysine should be X
#      tmp         =>  $directory           # directory for tmp_dir
#      tmp_dir     =>  $directory           # directory for temporary files
#
#  Some keys can be shortened.
#===============================================================================
sub find_selenoproteins
{
    my ( $params ) = @_;

    my ( $tmp_dir, $save_tmp ) = temporary_directory( $params );

    my ( $contig_key ) = grep { /^contig/ || /^gen/ } keys %$params;
    my $contigs = $contig_key ? $params->{ $contig_key } : undef;
    ( ref( $contigs ) eq 'ARRAY' ) && @$contigs
        or return ();

    my %contigR = map { $_->[0] => \$_->[2] } @$contigs;   #  Index sequence ref by id

    my ( $pyrro_key ) = grep { /^pyrrolys/ } keys %$params;
    my $pyrrolys = $pyrro_key ? $params->{ $pyrro_key } : 0;

    my ( $comment_key ) = grep { /^comment/ || /^note/ } keys %$params;
    my $comment = $comment_key ? $params->{ $comment_key } : '';

    #  Here are most of the differences between selenocysteine and
    #  pyrrolysine processing:

    my $my_stop = $pyrrolys ? 'TAG' : 'TGA';
    my $my_symb = $pyrrolys ? 'X'   : 'U';
    $comment  ||= $pyrrolys ? 'pyrrolysylprotein' : 'selenoprotein';

    my %gencode = %gjoseqlib::genetic_code;
    $gencode{ $my_stop } = $my_symb;

    #  Get reference sequences as parameter, or get them from a module:

    my ( $ref_key ) = grep { /^ref/ } keys %$params;
    my $refs = $ref_key ? $params->{ $ref_key } : undef;
    if ( $refs )
    {
        ( ref( $refs ) eq 'ARRAY' ) && @$refs
            or print STDERR "No reference sequences supplied to find_selenoproteins().\n"
               and return ();
    }
    elsif ( $pyrrolys )
    {
        eval
        {
            require pyrrolysylprotein_ref_seq;
            $refs = $pyrrolysylprotein_ref_seq::ref_seqs;
        };
        $refs && ( ref( $refs ) eq 'ARRAY' ) && @$refs
              or print STDERR "Unable to get reference sequences from pyrrolysylprotein_ref_seq.pm.\n"
                 and return ();
    }
    else
    {
        eval
        {
            require selenoprotein_ref_seq;
            $refs = $selenoprotein_ref_seq::ref_seqs;
        };
        $refs && ( ref( $refs ) eq 'ARRAY' ) && @$refs
              or print STDERR "Unable to get reference sequences from selenoprotein_ref_seq.pm.\n"
                 and return ();
    }

    #  Normally, the query (reference) amino acid must be U or X.  To avoid
    #  annoying formatdb messages, U is transliterated to X before writing
    #  the reference database.  To find a new selenoprotein, one option is
    #  to use a genome from a nonselenocysteine containing organism as the
    #  reference, and allow TGA codons to align with C in the reference
    #  sequence.  This option enables that function.  Otherwise C in the
    #  reference is not allowed to align with a proposed selenocysteine.
    #  Ditto for pyrrolysine.

    my ( $allow_key ) = grep { /^allow/ } keys %$params;
    my $ref_aa = $params->{ $allow_key } && $pyrrolys ? qr/[KX]/
               : $params->{ $allow_key }              ? qr/[CX]/
               :                                        qr/X/;

    my $suffix = $$ . "_" . sprintf( "%09d", int( 1e9 * rand() ) );

    #  Print and format the contig sequences:

    my $contig_file = "$tmp_dir/contigs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $contig_file, $contigs );
    -f $contig_file or return ();

    my $ext_bin = $FIG_Config::ext_bin;
    my $formatdb = $params->{ formatdb };
    $formatdb ||= $ext_bin ? "$ext_bin/formatdb" : 'formatdb';
    system "cd '$tmp_dir'; $formatdb -p f -i 'contigs_$suffix'";

    #  Make a clean copy of ref sequences to avoid BLAST warnings.

    $refs = [ map { my $s = uc $_->[2];      #  uppercase copy
                    $s =~ s/[BJOUZ]/X/g;     #  U etc. -> X
                    $s =~ s/[^A-Z]//g;       #  delete nonletters
                    [ @$_[0,1], $s ]
                  } @$refs
            ];
    my $ref_file = "$tmp_dir/refs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $ref_file, $refs );
    -f $ref_file or print STDERR "Failed to write reference sequences to $ref_file.\n"
                    and return ();

    #  Search the contigs for the reference sequences:

    my $blastall = $params->{ blastall };
    $blastall ||= $ext_bin ? "$ext_bin/blastall" : 'blastall';
    my $blastcmd = "$blastall -p tblastn -d '$contig_file' -i '$ref_file' "
                 . "-e 1e-10 -F f -b 200 -v 200 -a 2 |";
    open( BLAST, $blastcmd )
        or print STDERR "Could not open pipe '$blastcmd'.\n"
           and return ();
    my @hsps = gjoparseblast::blast_hsp_list( \*BLAST );
    close BLAST;

    #  Delete the temporary directory unless it already existed:

    system "/bin/rm -r $tmp_dir" if ! $save_tmp;

#
#  Stucture of the output records:
#
#   0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#  qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq
#

    @hsps = sort { $b->[6] <=> $a->[6] } @hsps;

    my $covered = {};
    my %hit = ();
    my %def = ();
    my $hsp;
    foreach $hsp ( @hsps )
    {
        #  This is a chance to filter out things that are already done.
        #  Currently, is_covered() returns 0

        next if is_covered( $hsp, $covered );

        #  List of locations with stops:

        my $i = 0;
        my ( $qid, $qdef, $sid, $scr, $qseq, $s1, $s2, $sseq ) = @$hsp[ 0, 1, 3, 6, 17, 18 .. 20 ];
        my @stops = map  { $i++; $_ eq '*' ? $i : () }
                    split //, $sseq;
        next if ! @stops;

        #  Changing the next statement might allow finding new instances.
        #  Unless a whole genome is used as a reference set, this is more
        #  likely to yield false positives than authentic selenoproteins,
        #  but it might be a useful exploratory tool.

        next if grep { substr( $qseq, $_-1, 1 ) !~ /$ref_aa/o } @stops;

        my $dir = $s2 <=> $s1;
        my $contigR    = $contigR{ $sid };
        my $contig_len = length( $$contigR );

        my $stop;
        my $is_okay = 1;
        foreach $stop ( @stops )
        {
            my $prefix = substr( $sseq, 0, $stop-1 );
            $prefix =~ s/-//g;
            my $n1 = $s1 + 3 * $dir * length( $prefix );
            my $n2 = $n1 + 2 * $dir;
            my $codon = uc gjoseqlib::DNA_subseq( $contigR, $n1, $n2 );
            $is_okay = ( ( $codon eq $my_stop ) ? 1 : 0 ) or last;
        }
        $is_okay or next;

        #  Follow the orf to a start:

        my ( $from, $partial_5 ) = find_orf_start( $contigR, $s1, $s2, $params );
        $from or next;

        #  Follow the orf to its end:

        my ( $to, $partial_3 ) = find_orf_end( $contigR, $s1, $s2, $params );
        $to or next;

        my $ntseq = uc DNA_subseq( $contigR, $from, $partial_3 ? $to : $to - 3*$dir );
        my $aaseq = translate_seq_with_user_code( $ntseq, \%gencode, ! $partial_5 );

        #  Save the protein unless we already have a longer hit to the same orf.

        my $key = "$sid\t$to\t$dir";
        my $len = length( $aaseq );
        $hit{$key} = [ $sid, $from, $to, $aaseq, $len ] unless ( $hit{$key} && $hit{$key}->[4] >= $len );
        $def{$key} = [ $qid, $qdef, $scr ]              unless ( $def{$key} && $def{$key}->[2] >= $scr );
    }

    #  Sort by contig and midpoint location, and return a hash of location,
    #  sequence and comment for each:

    my @prots = map  { scalar { location => join( '_', @$_[0..2] ),
                                sequence => $_->[3],
                                comment  => $comment,
                                ( $_->[5] ? ( reference_id  => $_->[5] ) : () ),
                                ( $_->[6] ? ( reference_def => $_->[6] ) : () )
                              }
                     }
                sort { $a->[0] cmp $b->[0] || ( ( $a->[1]+$a->[2] ) <=> ( $b->[1]+$b->[2] ) ) }
                map  { [ @{$hit{$_}}, @{$def{$_}} ] } # [ $sid, $from, $to, $aaseq, $len, $qid, $qdef, $scr ]
                keys %hit;

    wantarray ? @prots : \@prots;
}



#===============================================================================
#  Use a database of reference sequences to locate proteins in a genome.
#  Options allow alteration of intiator and terminator.
#
#      @locs = find_protein_homologs( \%params )
#
#  Required parameters:
#
#      contigs     => \@contigs             # genome is a synonym
#      references  => \@proteins            # selenocysteine must be U or X
#
#  Optional paramaters:
#
#      code        => \%genetic_code        # D = standard
#      code        =>  $NCBI_code_number    # D = standard
#      comment     =>  $comment_text        # comment is attached to each protein
#      expect      =>  $blast_e_value
#      is_init     => \@initiator_codons           # D = [ATG,GTG]
#      is_alt      => \@second_choice_init_codons  # D = [TTG]
#      is_term     => \@terminator_codons          # D = [TAA,TAG,TGA]
#      tmp         =>  $directory           # directory for tmp_dir
#      tmp_dir     =>  $directory           # directory for temporary files
#
#  Some keys can be shortened.
#===============================================================================
sub find_protein_homologs
{
    my ( $params ) = @_;

    my ( $tmp_dir, $save_tmp ) = temporary_directory( $params );

    my ( $contig_key ) = grep { $_ !~ /code/ }   # Don't get "genetic_code"
                         grep { /^contig/ || /^gen/ }
                         keys %$params;
    my $contigs = $contig_key ? $params->{ $contig_key } : undef;
    ( ref( $contigs ) eq 'ARRAY' ) && @$contigs
        or return ();

    my %contigR = map { $_->[0] => \$_->[2] } @$contigs;   #  Index sequence ref by id

    #  Get reference sequences as parameter:

    my ( $ref_key ) = grep { /^ref/ } keys %$params;
    my $refs;
    if ( ! ( $ref_key && ( $refs = $params->{ $ref_key } )
                      && ( ref( $refs ) eq 'ARRAY' )
                      && @$refs
           )
       )
    {
        print STDERR "No reference sequences supplied to find_protein_homologs().\n";
        return ();
    }

    #  Optional parameters

    my $comment = $params->{ comment } || 'Extracted by find_protein_homologs';

    my ( $exp_key ) = grep { /^exp/ } keys %$params;
    my $expect = $exp_key ? ( $params->{ $exp_key } + 0 ) : 1e-10;

    my ( $code_key ) = grep { /code/ } keys %$params;
    my %gencode;
    if ( $code_key )
    {
        my $code = $params->{ $code_key };
        if ( ref( $code ) eq 'HASH' )
        {
            %gencode = %$code;
        }
        elsif ( ref NCBI_genetic_code::genetic_code( $code ) eq 'HASH' )
        {
            %gencode = %{ NCBI_genetic_code::genetic_code( $code ) }
        }
        else
        {
            print STDERR "find_protein_homologs genetic code not a HASH reference.\n";
            return ();
        }
    }
    else
    {
        %gencode = %gjoseqlib::genetic_code;
    }

    #  Do the analysis

    #  Print and format the contig sequences:

    my $suffix = $$ . "_" . sprintf( "%09d", int( 1e9 * rand() ) );
    my $contig_file = "$tmp_dir/contigs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $contig_file, $contigs );
    -f $contig_file or return ();

    my $ext_bin = $FIG_Config::ext_bin;
    my $formatdb = $params->{ formatdb };
    $formatdb ||= $ext_bin ? "$ext_bin/formatdb" : 'formatdb';
    system "cd '$tmp_dir'; $formatdb -p f -i 'contigs_$suffix'";

    #  Make a clean copy of ref sequences to avoid BLAST warnings.

    $refs = [ map { my $s = uc $_->[2];      #  uppercase copy
                    $s =~ s/[BJOUZ]/X/g;     #  U etc. -> X
                    $s =~ s/[^A-Z]//g;       #  delete nonletters
                    [ @$_[0,1], $s ]
                  } @$refs
            ];
    my $ref_file = "$tmp_dir/refs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $ref_file, $refs );
    -f $ref_file or print STDERR "Failed to write reference sequences to $ref_file.\n"
                    and return ();

    #  Search the contigs for the reference sequences:

    my $blastall = $params->{ blastall };
    $blastall ||= $ext_bin ? "$ext_bin/blastall" : 'blastall';
    my $blastcmd = "$blastall -p tblastn -d '$contig_file' -i '$ref_file' "
                 . "-e $expect -F f -b 200 -v 200 -a 2 |";
    open( BLAST, $blastcmd )
        or print STDERR "Could not open pipe '$blastcmd'.\n"
           and return ();
    my @hsps = gjoparseblast::blast_hsp_list( \*BLAST );
    close BLAST;

    #  Delete the temporary directory unless it already existed:

    system "/bin/rm -r $tmp_dir" if ! $save_tmp;

#
#  Stucture of the output records:
#
#   0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#  qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq
#

    @hsps = sort { $b->[6] <=> $a->[6] } @hsps;

    my $covered = {};
    my %hit = ();
    my $hsp;
    foreach $hsp ( @hsps )
    {
        #  This is a chance to filter out things that are already done.
        #  Currently, is_covered() returns 0

        next if is_covered( $hsp, $covered );

        #  For the moment, no stops allowed:

        my ( $sid, $qseq, $s1, $s2, $sseq ) = @$hsp[ 3, 17, 18 .. 20 ];
        next if $sseq =~ /\*/;

        my $dir = $s2 <=> $s1;
        my $contigR    = $contigR{ $sid };
        my $contig_len = length( $$contigR );

        #  Follow the orf to a start:

        my ( $from, $partial_5 ) = find_orf_start( $contigR, $s1, $s2, $params );
        $from or next;

        #  Follow the orf to its end:

        my ( $to, $partial_3 ) = find_orf_end( $contigR, $s1, $s2, $params );
        $to or next;

        my $ntseq = uc DNA_subseq( $contigR, $from, $partial_3 ? $to : $to - 3*$dir );
        my $aaseq = translate_seq_with_user_code( $ntseq, \%gencode, ! $partial_5 );

        #  Save the protein unless we already have a longer hit to the same orf.

        my $key = "$sid\t$to\t$dir";
        my $len = length( $aaseq );
        $hit{$key} = [ $sid, $from, $to, $aaseq, $len ] unless ( $hit{$key} && $hit{$key}->[4] >= $len );
    }

    #  Sort by contig and midpoint location, and return a hash or location,
    #  sequence and comment for each:

    my @prots = map  { scalar { location => join( '_', @$_[0..2] ),
                                sequence => $_->[3],
                                comment  => $comment
                              }
                     }
                sort { $a->[0] cmp $b->[0] || ( ( $a->[1]+$a->[2] ) <=> ( $b->[1]+$b->[2] ) ) }
                map  { $hit{$_} }
                keys %hit;

    wantarray ? @prots : \@prots;
}


#-------------------------------------------------------------------------------
#  This is a place holder for minimizing duplicate analysis of orfs that
#  have already been found.  Currently, duplicates are removed by storing
#  proteins by end location and direction, saving the longest.
#-------------------------------------------------------------------------------
sub is_covered
{
    my ( $hsp, $covered ) = @_;
    0;
}


#-------------------------------------------------------------------------------
#  find_orf_start
#
#  ( $start, $is_partial ) = find_orf_start( \$contig, $s1, $s2, $options )
#
#  The start is defined by the first AUG or GUG upstream of $s1, or the
#  first UUG upstream of $s1.  The triplet starting with $s1 is
#  the initial search position.  If the search falls off an end of the
#  contig, then the $start marks the start of the last complete codon,
#  and $is_partial is true.  If extending the orf hits a stop before a
#  start, then we we truncate the orf to the start closest to $s1.  If
#  this fails, we return the empty list.
#
#  Options:
#
#    is_init => \@initiator_triplets                ( D = [ATG,GTG] )
#    is_alt  => \@second_choice_initiator_triplets  ( D = [TTG] )
#    is_term => \@terminator_triplets               ( D = [TAA,TAG,TGA] )
#
#-------------------------------------------------------------------------------
sub find_orf_start
{
    my ( $contigR, $s1, $s2, $options ) = @_;
    my $contig_len = length( $$contigR );
    my $dir = $s2 <=> $s1;

    #  Alternative start codons are only returned if essential to
    #  avoid a terminator:

    my %is_init = opt_hash( $options, 'is_init', [ qw( ATG GTG ) ] );
    my %is_alt  = opt_hash( $options, 'is_alt',  [ qw( TTG ) ] );
    my $alt_init;

    my %is_term = opt_hash( $options, 'is_term', [ qw( TAA TAG TGA ) ] );
    my $n1 = $s1;
    my $n2 = $n1 + 2 * $dir;
    
    my $extend = 1;
    while ( $extend )
    {
        my $codon = uc gjoseqlib::DNA_subseq( $contigR, $n1, $n2 );
        if ( $is_init{ $codon } )
        {
            return ( $n1, 0 );
        }
        elsif ( $is_term{ $codon } && ( $n1 != $s1 ) )
        {
            return ( $alt_init, 0 ) if $alt_init;
            $extend = 0;
        }
        #  Running off end of contig?
        elsif ( $dir > 0 ? $n1 - 3 < 1 : $n1 + 3 > $contig_len )
        {
            return ( $n1, 1 );
        }
        else
        {
            $alt_init = $n1 if ! $alt_init && $is_alt{ $codon };
            $n2 = $n1 -     $dir;
            $n1 = $n2 - 2 * $dir;
        }
    }

    #  We failed to extend the match region to an initiator,
    #  now we cut into it:

    $n1 = $s1;
    $n2 = $n1 + 2 * $dir;
    while ( 1 )
    {
        #  Running off end of match region?
        if  ( $dir > 0 ? $n2 + 3 > $s2 : $n2 - 3 < $s2 )
        {
            return ();
        }
        $n1 = $n2 +     $dir;
        $n2 = $n1 + 2 * $dir;
        my $codon = uc gjoseqlib::DNA_subseq( $contigR, $n1, $n2 );
        if ( $is_init{ $codon } || $is_alt{ $codon } )
        {
            return ( $n1, 0 );
        }
    }
}


#-------------------------------------------------------------------------------
#  ( $end, $is_partial ) = find_orf_end( \$contig, $s1, $s2, $options )
#
#  The end is defined as the first UAA, UAG or UGA downstream of $s2.  If
#  not end is found before the end of the contig, then $is_partial is true.
#
#  Options:
#
#    is_term => \@terminator_triplets               ( D = [TAA,TAG,TGA] )
#
#-------------------------------------------------------------------------------
sub find_orf_end
{
    my ( $contigR, $s1, $s2, $options ) = @_;
    my $contig_len = length( $$contigR );
    my $dir = $s2 <=> $s1;

    my %is_term = opt_hash( $options, 'is_term', [ qw( TAA TAG TGA ) ] );

    my $n2 = $s2;
    my $n1 = $n2 - 2 * $dir;
    while ( 1 )
    {
        #  Running off end of contig?
        if  ( $dir > 0 ? $n2 + 3 > $contig_len : $n2 - 3 < 1 )
        {
            return ( $n2, 1 );
        }
        $n1 = $n2 +     $dir;
        $n2 = $n1 + 2 * $dir;
        my $codon = uc gjoseqlib::DNA_subseq( $contigR, $n1, $n2 );
        if ( $is_term{ $codon } )
        {
            return ( $n2, 0 );
        }
    }
}


#-------------------------------------------------------------------------------
#  Fill a hash with key => value pairs based on a has or an array in \%options,
#  or a supplied default list or hash:
#
#     %hash = opt_hash( \%options, $opt_name, \@defaults )
#     %hash = opt_hash( \%options, $opt_name, \%defaults )
#
#-------------------------------------------------------------------------------
sub opt_hash
{
    my ( $options, $opt_name, $defaults ) = @_;
    ( ref( $options ) eq 'HASH' && $opt_name ) or ref( $defaults ) or return ();

    $defaults = $options->{ $opt_name } if ref( $options ) && ref( $options->{ $opt_name } );

    ref( $defaults ) eq 'ARRAY' ? map { $_ => 1 } @$defaults :
    ref( $defaults ) eq 'HASH'  ? %$defaults                 :
                                  ()
}


#-------------------------------------------------------------------------------
#  ( $tmp_dir, $save_tmp ) = temporary_directory( \%options )
#-------------------------------------------------------------------------------
sub temporary_directory
{
    my $options = ( shift ) || {};

    #  Accept these option names with or without an underscore
    my $tmp_dir  = $options->{ tmpdir }  || $options->{ tmp_dir };
    my $save_tmp = $options->{ savetmp } || $options->{ save_tmp } || '';

    if ( $tmp_dir )
    {
        #  User-supplied directory?  Don't blow it away when we're done
        if ( -d $tmp_dir ) { $options->{ savetmp } = $save_tmp = 1 }
    }
    else
    {
        my $tmp = $options->{ tmp } && -d  $options->{ tmp } ?  $options->{ tmp }
                : $FIG_Config::temp && -d  $FIG_Config::temp ?  $FIG_Config::temp
                :                      -d '/tmp'             ? '/tmp'
                :                                              '.';
        $tmp_dir = sprintf( "$tmp/special_proteins_tmp_dir.%05d.%09d", $$, int(1000000000*rand) );
        #  We named the directoy, let's add it in the options hash
        $options->{ tmpdir } = $tmp_dir;
    }

    if ( $tmp_dir && ! -d $tmp_dir )
    {
        mkdir $tmp_dir;
        if ( ! -d $tmp_dir )
        {
            print STDERR "find_special_proteins::temporary_directory could not create '$tmp_dir'\n";
            $options->{ tmpdir } = $tmp_dir = undef;
        }
    }

    return ( $tmp_dir, $save_tmp );
}

#===============================================================================
#  Use a database of reference sequences to locate proteins with unusual starts in a genome.
#
#      @locs = find_odd_starts( \%params )
#
#  Required parameters:
#
#      contigs     => \@contigs             # genome is a synonym
#
#  Optional paramaters:
#
#      comment     =>  $text                # comment for output hash
#      is_term     => \@terminator_codons          # D = [TAA,TAG,TGA]
#      note        =>  $text                # same as 'comment'
#      references  => \@odd_start_proteins  # user-supplied references
#      tmp         =>  $directory           # directory for tmp_dir
#      tmp_dir     =>  $directory           # directory for temporary files
#
#  Some keys can be shortened.
#===============================================================================
sub find_odd_starts
{
    my ( $params ) = @_;
    my %locs;
    my ( $tmp_dir, $save_tmp ) = temporary_directory( $params );

    my ( $contig_key ) = grep { /^contig/ || /^gen/ } keys %$params;
    my $contigs = $contig_key ? $params->{ $contig_key } : undef;
    ( ref( $contigs ) eq 'ARRAY' ) && @$contigs
        or return ();

    my %contigR = map { $_->[0] => \$_->[2] } @$contigs;   #  Index sequence ref by id

    my ( $comment_key ) = grep { /^comment/ || /^note/ } keys %$params;
    my $comment = $comment_key ? $params->{ $comment_key } : '';

    #  Get reference sequences as parameter, or get them from a module:

    my ( $ref_key ) = grep { /^ref/ } keys %$params;
    my $refs = $ref_key ? $params->{ $ref_key } : undef;
    if ( $refs )
    {
        ( ref( $refs ) eq 'ARRAY' ) && @$refs
            or print STDERR "No reference sequences supplied to find_odd_starts().\n"
               and return ();
    }
    else
    {
        eval
        {
            require OddStarts_ref;
            $refs = $OddStarts_ref::ref_seqs;
        };
        $refs && ( ref( $refs ) eq 'ARRAY' ) && @$refs
              or print STDERR "Unable to get reference sequences from OddStarts_ref.pm.\n"
                 and return ();
    }
    my $suffix = $$ . "_" . sprintf( "%09d", int( 1e9 * rand() ) );

    #  Print and format the contig sequences:

    my $contig_file = "$tmp_dir/contigs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $contig_file, $contigs );
    -f $contig_file or return ();

    my $ext_bin = $FIG_Config::ext_bin;
    my $formatdb = $params->{ formatdb };
    $formatdb ||= $ext_bin ? "$ext_bin/formatdb" : 'formatdb';
    system "cd '$tmp_dir'; $formatdb -p f -i 'contigs_$suffix'";

    #  Make a clean copy of ref sequences to avoid BLAST warnings.

    $refs = [ map { my $s = uc $_->[2];      #  uppercase copy
                    $s =~ s/[BJOUZ]/X/g;     #  U etc. -> X
                    $s =~ s/[^A-Z]//g;       #  delete nonletters
                    [ @$_[0,1], $s ]
                  } @$refs
            ];
    my $ref_file = "$tmp_dir/refs_$suffix";
    gjoseqlib::print_alignment_as_fasta( $ref_file, $refs );
    -f $ref_file or print STDERR "Failed to write reference sequences to $ref_file.\n"
                    and return ();

    #  Search the contigs for the reference sequences:

    my $blastall = $params->{ blastall };
    $blastall ||= $ext_bin ? "$ext_bin/blastall" : 'blastall';
    my $blastcmd = "$blastall -p tblastn -d '$contig_file' -i '$ref_file' "
                 . "-e 1e-10 -F f -b 200 -v 200 -a 2 |";
    open( BLAST, $blastcmd )
        or print STDERR "Could not open pipe '$blastcmd'.\n"
           and return ();
    my @hsps = gjoparseblast::blast_hsp_list( \*BLAST );
    close BLAST;

    #  Delete the temporary directory unless it already existed:

    system "/bin/rm -r $tmp_dir" if ! $save_tmp;

#
#  Stucture of the output records:
#
#   0   1    2    3   4    5    6    7    8    9    10    11   12    13   14  15 16  17  18 19  20
#  qid qdef qlen sid sdef slen scr e_val p_n p_val n_mat n_id n_pos n_gap dir q1 q2 qseq s1 s2 sseq
#

    @hsps = sort { $b->[6] <=> $a->[6] } @hsps;

    my $covered = {};
    my %hit = ();
    my %def = ();
    my $hsp;

    foreach $hsp ( @hsps )
    {

	if ((($hsp->[11] / $hsp->[10]) > 0.6) && (($hsp->[10] / $hsp->[2]) > 0.9))
	{
	    my $contig  = $hsp->[3];
	    my $contigP = $contigR{$contig};
	    my $beg     = $hsp->[18];
	    my $end     = $hsp->[19];
	    my ($predE,$partial)  = &find_orf_end($contigP,$beg,$end,$params);
	    if ($predE && (! $partial))
	    {
#		my($predS,$partial) = &find_orf_start($contigP,$begA,$end,{is_init => ['ATT']});
		my($predS,$partial) = (($beg < $end) ? ($beg - (($hsp->[15] - 1) * 3)) :
				       ($beg + (($hsp->[15] - 1) * 3)),0);
		if ($predS && (! $partial))
		{
		    my $loc   = join("_",($contig,$predS,$predE));
		    $locs{$loc}++;
		}
	    }
	}
	else
	{
#	    print STDERR &Dumper($hsp);
	}
    }
    my(@locs) = sort keys(%locs);
    wantarray ? @locs : \@locs;
}

1;
