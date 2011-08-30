package gjonativecodonlib;
#
#  A library of functions for finding native (modal and high expression)
#  codon usage of a genome.
#

#
# This is a SAS Component
#

use strict;
use SeedAware       qw( location_of_tmp
                        new_file_name
                      );
use bidir_best_hits qw( bbh );
use gjocodonlib     qw( codon_freq_distance
                        count_vs_freq_chi_sqr
                        seq_codon_count_package
                        report_frequencies
                        modal_codon_usage
                        project_on_freq_vector_by_chi_sqr_2
                        report_counts
                      );
use gjoseqlib       qw( translate_seq );
use gjostat         qw( chisqr_prob mean_stddev );
use IPC::Open2      qw( open2 );
# use Data::Dumper;

require Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw( find_axis
                  native_codon_usage
                );

my $usage = <<'End_of_Comments';
Find the modal and high expression codon usage of a genome.

   @mode_label_pairs = native_codon_usage( \%params )

The first mode returned is that of the genome.  By default, the second mode
returned is the final estimate.  If all_he_modes is true, then the series of
estimates is included.

Required parameter:

    dna => \@dna_entries  # required

Optional parameters:

    all_he_modes     => bool           # D = 0       # show successive high expr approximations
    average          => bool           # D = undef   # include the average codon usage
    bbh_blast_opts   => opts           # D = ''      # none
    bbh_coverage     => frac           # D = 0.70    # bbh covers 70% of gene
    bbh_e_value      => e_value        # D = 1e-5    # bbh match at least 1e-5 (could relax a little)
    bbh_identity     => frac           # D = 0.20    # bbh 20% amino acid identity
    bbh_positives    => frac           # D = 0.30    # bbh 30% amino acids with positive score
    bias_stats       => bool           # D = undef   # don't do bias statistics
    counts_file      => file           # D = ''      # none
    genome_title     => string         # D = ''      # prefix to each mode label
    log              => file_handle    # D = STDERR  # (if log_label is supplied)
    log_label        =>                # D = ''      # no log
    he_ref_module    => perl_module    # D ='high_expression_ref_ab';
    match_p_value    => p_value        # D = 0.10;   # a match it mode is P > 0.1
    max_he_decline   => fraction       # D = 0.20    # < 20% decline in finding original he candidates
    max_iter         => int            # D = 2       # original estimate and 2 refinements
    max_keep         => int or frac    # D = 0.10    # keep up to 10% of genome
    max_mode_overlap => frac           # D = 0.80    # < 80% of genes matching he can match mode
    min_he_genes     => int            # D = 20      # don't estimate with < 20 bbh genes
    min_nonmodal     => frac           # D = 0.20    # 20% of candidates differ from genome mode
    min_x_value      => frac           # D = 0.50    # >%50 of way from mode to he estimate
    mode_exponent    => real           # D = 0.30    # exponent of P-value in mode calculation
    nonnative     l  => bool           # D = 0       # do not do nonnative
    omit_p_value     => p_value        # D = 0.10    # omit from high exp calc if P > 0.1 to mode
    p_val_max_len    => int            # D = undef;  # no limit on length in chi-square
    reach_p_value    => p_value        # D = 0.05    # allow direction to drift

Special parameters that change the function, or return values:

   algorithm => bool  # if true, the function returns the algorthm description
   usage     => bool  # if true, the function returns this usage description
   version   => bool  # if true, the function returns the version string

If none of these are true, then the analysis is performed, and the following
assignments are made:

   $param->{ algorithm } = \$algorithm_description
   $param->{ usage }     = \$usage_description
   $param->{ version }   =  $version_string

End_of_Comments

my $algorithm = <<'End_of_Algorithm';
Details of the Algorithm and Parameters:

Find the native (modal and high expression) codon usages of a genome.
The algorithm can be summarized as:

1.  Find the modal codon usage of the genome.

    Relevant paramter:

        mode_exponent -
             Exponent of P-value in optimizing the mode.

2.  Identify a set of candidate high expression genes by finding the genes
    that are bidirectional best hits to presumptively abundant proteins from
    a reference genome.

    Relevant paramters:

        bbh_blast_opts -
             Blast program options (note: most blast options are ignored).
                Perhaps the most useful is '-a 4' for using 4 threads.
        bbh_coverage -
             Minimum fraction of query and subject sequence lengths covered
                in blast matches
        bbh_e_value -
             Maximum blast E-value
        bbh_identity -
             Minimum (fraction) sequence identity in blast matches
        bbh_positives -
             Minimun (fraction) amino acid matches with positive score in
                blast search
        he_ref_module -
             Perl module with reference genome and high expression gene list

3.  Use a set of candidate high expression genes (from step 2 or step 5) to
    estimate the high expression codon usage of the genome. In detail:

    3a. Remove from the candidate high expression genes those that are too
        similar to the overall mode (from step 1).

        Relevant paramters:

            min_nonmodal -
                 Fraction of candidate high expression genes that must differ
                    significantly from the genome mode for fillering to occur
            omit_p_value -
                 Genes that match mode with P > omit_p_value are usually
                    omitted from high expression estimate.  Thus,l
                    omit_p_value => 1 wil use all of the genes.
            p_val_max_len -
                 Length limit in calculating match of protein to the modal
                    codon usage. Longer proteins have their chi-square scaled
                    down before calculating the P-value, so large genes appear
                    to match better.

    3b. Find the modal usage of the remaining candidate high expression genes.

        Relevant paramter:

            min_he_genes -
                 Number of candidate high expression genes for the mode to
                    be computed

4.  Terminate if a stopping condition is reached.

        Relevant paramters:

            max_iter -
                 Number of iterations of refinement, that is cycles of steps
                    5, 3, and 4
            min_nonmodal -
                 Fraction of candidate high expression genes that must be
                    distinct (significantly different) from the modal codon
                    usage for the iterations to continue

5.  Otherwise, produce a new set of candidate high expression genes. In detail:

    5a. Limit to genes that are within "reach P-value" of current
        "mode to high expression" axis

        Relevant paramters:

            p_val_max_len -
                 Length limit in calculating match of protein to the modal
                    codon usage. Longer proteins have their chi-square scaled
                    down before calculating the P-value, so large genes appear
                    to match better.
            reach_p_value -
                 Minimum P-value of a match to the mode to high expression
                    axis for the gene to be included in the next estimate.
                    This defines which genes are within "reach" for influencing
                    the next mode calculation. The goal is to allow migration
                    of the estimate within a constrained space.

    5b. Limit to genes with x value greater than or equal to "min x value".

        Relevant paramter:

            min_x_value -
                 Minium value of x for inclusion as candidate high expression
                    gene. For any given iteration, either max_keep or
                    min_x_value will be limiting, as they both monitor the
                    x value of the genes.

    5c. Limit to "max keep" highest x values (most high expression like).

        Relevant paramter:

            max_keep -
                 Maxium number of candidate high expression genes kept for the
                    next estimate (before removing those that match the mode).
                    For any given iteration, either max_keep or min_x_value
                    will be limiting, as they both monitor the x value of the
                    genes.

    5d. Go to step 3. This means that max keep (max_keep value) is enforced
        before removing the mode-matching genes.

End_of_Algorithm

#===============================================================================
#  Find the genome modal codon usage, and one or more estimates of the high
#  expression codon usage.
#
#  ( $genome_mode, @high_exp_mode_ests ) = native_codon_usage( \%options )
#
#  Each mode is a mode-label pair.  With valid data, the genome mode should
#  always be returned.  The caller is responsible for obvious filtering,
#  such as minimum DNA sequence length.
#===============================================================================

sub native_codon_usage
{
    $_[0] && ref $_[0] eq 'HASH' or return undef;

    my $version = '1.00';
    my $param = $_[0];

    #  Special requests:

    return $version   if ( $param->{ version }   && $param->{ version }   ne  $version );
    return $usage     if ( $param->{ usage }     && $param->{ usage }     ne \$usage );
    return $algorithm if ( $param->{ algorithm } && $param->{ algorithm } ne \$algorithm );

    #  Otherwise, link the information into the calling paramter array:

    $param->{ version }   =  $version;    #  Return version version
    $param->{ usage }     = \$usage;      #  Return usage information
    $param->{ algorithm } = \$algorithm;  #  Return algorithm information

    # use high_expression_bacteria qw( &ref_aa &ref_he )   # embedded in the code

    #  \$(\S+)(\s*)=
    #  $\1\2= defined( $param->{ \1 } )\2? $param->{ \1 }\2:

    #  Parameters that the user can change:

    my $all_he_modes     = defined( $param->{ all_he_modes } )     ? $param->{ all_he_modes }     :     0;      # include successive approximations
    my $average          = defined( $param->{ average } )          ? $param->{ average }          :     0;      # include average as first frequency
    my $bbh_blast_opts   = defined( $param->{ bbh_blast_opts } )   ? $param->{ bbh_blast_opts }   :    '';
    my $bbh_coverage     = defined( $param->{ bbh_coverage } )     ? $param->{ bbh_coverage }     :     0.70;   # bbh covers 70% of gene
    my $bbh_e_value      = defined( $param->{ bbh_e_value } )      ? $param->{ bbh_e_value }      :  1e-5;      # bbh match at least 1e-5 (could relax a little)
    my $bbh_identity     = defined( $param->{ bbh_identity } )     ? $param->{ bbh_identity }     :     0.20;   # bbh 20% amino acid identity
    my $bbh_positives    = defined( $param->{ bbh_positives } )    ? $param->{ bbh_positives }    :     0.30;   # bbh 30% amino acids with positive score
    my $bias_stats       = defined( $param->{ bias_stats } )       ? $param->{ bias_stats }       : undef;      # don't do bias statistics
    my $counts_file      = defined( $param->{ counts_file } )      ? $param->{ counts_file }      :    '';      # don't save the counts
    my $dna              = defined( $param->{ dna } )              ? $param->{ dna }              :    [];
    my $genome_title     = defined( $param->{ genome_title } )     ? $param->{ genome_title }     :    '';      # prefix for codon frequency labels
    my $he_ref_module    = defined( $param->{ he_ref_module } )    ? $param->{ he_ref_module }    : 'high_expression_ref_ab';
    my $initial_he_ids   = defined( $param->{ initial_he_ids } )   ? $param->{ initial_he_ids }   : undef;
    my $log              = defined( $param->{ log } )              ? $param->{ log }              :    '';      # file handle for log
    my $log_label        = defined( $param->{ log_label } )        ? $param->{ log_label }        :    '';
    my $match_p_value    = defined( $param->{ match_p_value } )    ? $param->{ match_p_value }    :     0.10;   #
    my $max_he_decline   = defined( $param->{ max_he_decline } )   ? $param->{ max_he_decline }   :     0.20;   # < 20% decline in finding original he candidates
    my $max_iter         = defined( $param->{ max_iter } )         ? $param->{ max_iter }         :     2;      # original estimate and 2 refinements
    my $max_keep         = defined( $param->{ max_keep } )         ? $param->{ max_keep }         :     0.10;   # 10% of the genome
    my $max_mode_overlap = defined( $param->{ max_mode_overlap } ) ? $param->{ max_mode_overlap } :     0.80;   # < 80% of genes matching he can match mode
    my $min_he_genes     = defined( $param->{ min_he_genes } )     ? $param->{ min_he_genes }     :    20;      # don't estimate with < 20 bbh genes
    my $min_nonmodal     = defined( $param->{ min_nonmodal } )     ? $param->{ min_nonmodal }     :     0.20;   # 20% of candidates differ from genome mode
    my $min_x_value      = defined( $param->{ min_x_value } )      ? $param->{ min_x_value }      :     0.50;   #
    my $mode_exponent    = defined( $param->{ mode_exponent } )    ? $param->{ mode_exponent }    :     0.30;   # exponent of P-value in mode calculation
    my $nonnative        = defined( $param->{ nonnative } )        ? $param->{ nonnative }        :     0;      # do not do nonnative
    my $omit_p_value     = defined( $param->{ omit_p_value } )     ? $param->{ omit_p_value }     :     0.10;   # P > 0.1 to mode for omission from he calc
    my $p_val_max_len    = defined( $param->{ p_val_max_len } )    ? $param->{ p_val_max_len }    : undef;      # no limit on length in chi-square
    my $reach_p_value    = defined( $param->{ reach_p_value } )    ? $param->{ reach_p_value }    :     0.05;   # allow direction to drift

    if ( $bias_stats ) { $all_he_modes = 0; $max_iter = 0; $omit_p_value = 1 }

    $log = \*STDERR if ( $log || $log_label ) && ref( $log ) ne 'GLOB';
    $log_label = $genome_title || 'Unidentified DNA' if $log && ! $log_label;

    my $usage_prefix = $genome_title ? "$genome_title -- " : '';

    #---------------------------------------------------------------------------
    #  Index DNA and translate to amino acids:
    #---------------------------------------------------------------------------

    $dna && ( ref( $dna ) eq 'ARRAY' ) && @$dna
        or print STDERR "native_codon_usage() called with bad 'dna' parameter value.\n"
           and return ();

    my %dna = map { $_->[0] => $_ } @$dna;
    my $n_gene = @$dna;

    #  If $max_keep is fraction of genes, adjust to the number of genes.

    $max_keep = int( $max_keep * $n_gene + 0.5 ) if $max_keep <= 1;

    my $aa;
    my @aa  = map { $aa = gjoseqlib::translate_seq( $_->[2], 1 );
                    $aa =~ s/\*$//;
                    [ @$_[0,1], $aa ]
                  }
              @$dna;

    #---------------------------------------------------------------------------
    #  Codon usage counts for all of the genes:
    #---------------------------------------------------------------------------

    if ( $log )
    {
        print  $log "$log_label\n";
        printf $log "%7d total genes.\n\n", $n_gene;
        print  $log "Overall codon usage.\n";
    }

    #  Build: [ id, def, counts ]
    my @labeled_counts = map { [ @$_[0,1], gjocodonlib::seq_codon_count_package( $_->[2] ) ] } @$dna;
    #  Just the counts
    my @gen_counts     = map { $_->[2] }  @labeled_counts;
    #  Counts indexed by id
    my %gen_counts     = map { @$_[0,2] } @labeled_counts;
    #  Counts with full description
    my @gen_cnt_ids    = map { [ $_->[2], join( ' ', grep { $_ } @$_[0,1] ) ] } @labeled_counts;

    my $save_cnt_file = $counts_file ? 1 : 0;
    if ( $counts_file )
    {
        $counts_file .= '.counts' if $counts_file !~ /\./;   #  Add extension if necessary
    }
    else
    {
        my $tmp      = SeedAware::location_of_tmp( $param );
        $counts_file = SeedAware::new_file_name( "$tmp/native_codon_usage", 'counts' );
    }

    if ( ( @gen_counts >= 6 ) || $save_cnt_file )
    {
        open( CNT, ">$counts_file" )
            or print STDERR "native_codon_usage could not open '$counts_file' for writing.\n"
               and exit;
        if ( $save_cnt_file ) { foreach ( @gen_cnt_ids ) { report_counts( \*CNT, @$_ ) } }
        else                  { foreach ( @gen_counts  ) { report_counts( \*CNT,  $_ ) } }
        close CNT;
    }

    my @modes;

    #---------------------------------------------------------------------------
    #  Find average codon usage if:
    #     it is requested,
    #     a log is requested (to show number of genes matching), or
    #     there are not enough genes for a mode
    #---------------------------------------------------------------------------

    my ( $aver_freq, $n_match_average );
    if ( $average || $log || ( @gen_counts < 6 ) )
    {
        $aver_freq = gjocodonlib::count_to_freq( gjocodonlib::sum_counts( \@gen_counts ), 1 );
        $n_match_average = grep { $_->[1] >= $match_p_value }
                           cnts_and_p_values( $aver_freq, \@gen_counts, $p_val_max_len );
        if ( $average || ( @gen_counts < 6 ) )
        {
            push @modes, [ $aver_freq, $usage_prefix . 'Genome average' ];
        }
    }

    #  If there are too few counts for mode, we are done:

    if ( @gen_counts < 6 )
    {
        if ( $log )
        {
            print  $log " *** Too few genes ($n_gene < 6) for mode; reporting average usage.\n";
            printf $log "%7d genes match (%.1f%%) the genome average (P >= $match_p_value).\n\n",
                         $n_match_average, 100*$n_match_average/$n_gene;
        }
        return @modes;
    }

    #---------------------------------------------------------------------------
    #  Genome mode and genes matching it:
    #---------------------------------------------------------------------------

    my $mode_opts = { count_file => $counts_file,
                      exponent   => $mode_exponent,
                      quiet      => 1
                    };
    my $gen_mode = gjocodonlib::modal_codon_usage( \@gen_counts, $mode_opts );

    push @modes, [ $gen_mode, $usage_prefix . 'Genome mode' ];

    #  Genes matching genome mode (this might have different p-value than omission)

    my @mode_p_vals = cnts_and_p_values( $gen_mode, \@gen_counts, $p_val_max_len );
    my %match_mode = map { $_->[1] >= $match_p_value ? ( $_->[0] => 1 ) : () } @mode_p_vals;
    my $n_match = keys %match_mode;

    #  Record genes to be omitted from high expression calculation due to
    #  similarity to genome mode

    my %omit = map { $_->[1] >= $omit_p_value ? ( $_->[0] => 1 ) : () } @mode_p_vals;
    my $n_omit = keys %omit;

    if ( $log )
    {
        printf $log "%7d genes match (%.1f%%) the genome average (P >= $match_p_value).\n",
                     $n_match_average, 100*$n_match_average/$n_gene;
        printf $log "%7d genes match (%.1f%%) the overall mode (P >= $match_p_value).\n",
                     $n_match, 100*$n_match/$n_gene;
        printf $log "%7d genes marked for omission due to matching the mode (P >= $omit_p_value).\n",
                     $n_omit;
        print  $log "\n";
    }

    #---------------------------------------------------------------------------
    #  Find homologs of high expression genes in reference genome:
    #---------------------------------------------------------------------------

    if ( $log ) { print  $log "Initial high expression representatives.\n" }

    my @he_id;
    if ( $initial_he_ids && ref( $initial_he_ids ) eq 'ARRAY' )
    {
        my %seen;
        @he_id = grep { $dna{ $_ } && ! $seen{ $_ }++ } @$initial_he_ids;
        if ( $log )
        {
            printf $log "%7d high expression genes defined by calling program.\n",
                         scalar @$initial_he_ids;
            printf $log "%7d have ids in the DNA data.\n",
                         scalar @he_id;
        }
    }

    if ( @he_id < $min_he_genes )
    {
        $he_ref_module =~ s/\.pm$//;    # remove .pm, if present
        eval( "use $he_ref_module qw( \&ref_aa \&ref_he )" );
        my @ref_aa   = &high_expression_ref::ref_aa();
        my @ref_he   = &high_expression_ref::ref_he();

        my %ref_he   = map { $_ => 1 } @ref_he;
        my $n_ref_he = @ref_he;

        my $bbh_opt = { blast_opts    => $bbh_blast_opts,
                        max_e_value   => $bbh_e_value,
                        min_coverage  => $bbh_coverage,
                        min_identity  => $bbh_identity,
                        min_positives => $bbh_positives,
                        program       => 'blastp',
                        subset        => \@ref_he
                      };

        my ( $bbh ) = bidir_best_hits::bbh( \@ref_aa, \@aa, $bbh_opt );

        @he_id = map { $_->[1] } grep { $ref_he{ $_->[0] } } @$bbh;

        if ( $log )
        {
            printf $log "%7d high expression genes defined in reference genome.\n",
                         $n_ref_he;
            printf $log "%7d bidirectional best hits to high expression genes identified.\n",
                         scalar @he_id;
        }

        $param->{ initial_he_ids } = [ @he_id ];  #  Potentially dicy, but ....
    }

    if ( $log ) { print  $log "\n" }

    #  Open a pipe for evaluating matches to an axis:

    my $x_p_eval_pipe = open_evaluation_pipe( $counts_file, $p_val_max_len );

    #---------------------------------------------------------------------------
    #  High expression gene mode:
    #
    #  All of the values in find_axis are indexed by their codon counts
    #  reference; there are no ids per se.
    #---------------------------------------------------------------------------

    my @he_counts    = map { $gen_counts{ $_ } } @he_id;
    my $he_mode_opts = {};

    my $he_axis_param = { axis_name        => 'High expression',
                          genome_counts    => \@gen_counts,
                          genome_mode      =>  $gen_mode,
                          genome_title     =>  $genome_title,
                          log              =>  $log,
                          match_p_value    =>  $match_p_value,
                          max_iterations   =>  $max_iter,
                          max_keep         =>  $max_keep,
                          max_mode_overlap =>  $max_mode_overlap,
                          max_target_loss  =>  $max_he_decline,
                          min_nonmodal     =>  $min_nonmodal,
                          min_targets      =>  $min_he_genes,
                          min_x_value      =>  $min_x_value,
                          mode_matches     => \%match_mode,
                          mode_options     =>  $he_mode_opts,
                          omit_counts      => \%omit,
                          omit_p_value     =>  $omit_p_value,
                          p_val_max_len    =>  $p_val_max_len,
                          reach_p_value    =>  $reach_p_value,
                          target_counts    => \@he_counts,
                          mode_prefix      =>  $usage_prefix,
                          x_p_eval_pipe    =>  $x_p_eval_pipe,
                        };

    my @high_expr_modes = find_axis( $he_axis_param );

    @high_expr_modes = ( $high_expr_modes[-1] ) if ! $all_he_modes;

    #---------------------------------------------------------------------------
    #  Nonnative gene mode:
    #---------------------------------------------------------------------------

    my @nonnative_modes;
    if ( $nonnative )
    {
        my %match_native;
        my %omit2;
        if ( @high_expr_modes && $high_expr_modes[-1]->[1] !~ /including those matching the mode/ )
        {
            my $high_expr_mode = $high_expr_modes[-1]->[0];

            #  Match of all genes to the mode -> high expression axis.
            #  Each projection is [ $cnt, $x, $p ]

            my @projections = cnts_x_and_p( $x_p_eval_pipe, $gen_mode, $high_expr_mode, \@gen_counts, $p_val_max_len );

            #  Match to target axis with x >= 0 (if x < 0, then test is
            #  matching the mode).

            %match_native = map  { $_->[0] => 1 }
                            grep { $match_mode{ $_->[0] } || ( $_->[1] >= 0 && $_->[2] >= $match_p_value ) }
                            @projections;

            #  Match to target axis with x >= 0 (if x < 0, then test is
            #  matching the mode).

            %omit2 = map  { $_->[0] => 1 }
                     grep { $omit{ $_->[0] } || ( $_->[1] >= 0 && $_->[2] >= $omit_p_value ) }
                     @projections;
        }
        else
        {
            %match_native = %match_mode;
            %omit2 = %omit;
        }

        my @target_counts = grep { ! $omit2{ $_ } } @gen_counts;

        my $nn_axis_param = { axis_name        => 'Nonnative',
                              genome_counts    => \@gen_counts,
                              genome_mode      =>  $gen_mode,
                              genome_title     =>  $genome_title,
                              log              =>  $log,
                              match_p_value    =>  $match_p_value,
                              max_iterations   =>  $max_iter,
                              max_keep         =>  $max_keep,
                              max_mode_overlap =>  $max_mode_overlap,
                              max_target_loss  =>  $max_he_decline,    # ???
                              min_nonmodal     =>  $min_nonmodal,
                              min_targets      =>  $min_he_genes,      # ???
                              min_x_value      =>  $min_x_value,
                              mode_matches     => \%match_native,
                              mode_options     =>  $he_mode_opts,
                              omit_counts      => \%omit2,
                              omit_p_value     =>  $omit_p_value,
                              p_val_max_len    =>  $p_val_max_len,
                              reach_p_value    =>  $reach_p_value,
                              target_counts    => \@target_counts,
                              mode_prefix      =>  $usage_prefix,
                              x_p_eval_pipe    =>  $x_p_eval_pipe,
                            };

        @nonnative_modes = find_axis( $nn_axis_param );

        @nonnative_modes = ( $nonnative_modes[-1] ) if ! $all_he_modes;
    }

    #---------------------------------------------------------------------------
    #  Finish:
    #---------------------------------------------------------------------------

    close_pipe2( $x_p_eval_pipe ) if $x_p_eval_pipe;
    unlink $counts_file  if ! $save_cnt_file;

    if ( $bias_stats && @high_expr_modes )
    {
        #  Find distance between mode and he mode:

        my $dist = gjocodonlib::codon_freq_distance( $gen_mode, $high_expr_modes[0]->[0] );

        #  Do same for 10 random subsets of initial gene set.

        my $set_size = @{ $param->{ initial_he_ids } };
        my @dists;

        for ( my $i = 0; $i < 10; $i++ )
        {
            my @cnts2 = ( sort { rand() <=> 0.5 } @gen_counts )[ 0 .. ($set_size-1) ];
            my $freq2 = gjocodonlib::modal_codon_usage( \@cnts2, {} );
            push @dists, gjocodonlib::codon_freq_distance( $gen_mode, $freq2 );
        }

        my ( $mean, $stddev ) = gjostat::mean_stddev( @dists );
        my $Z = ( $dist - $mean ) / $stddev;
        my $stats = sprintf "distance = %5.3f; random = %5.3f +/- %5.3f; Z = %.1f", $dist, $mean, $stddev, $Z;
        $high_expr_modes[0]->[1] = "High expression mode: $stats";
    }

    ( @modes, @high_expr_modes, @nonnative_modes );
}


#===============================================================================
#  Just subroutines below:
#===============================================================================
#
#       $x_p_eval_pipe = open_evaluation_pipe( $counts_file, $l_max );
#
#  where,
#
#       $x_p_eval_pipe = [ $pid, $rw, $wr ]
#
#-------------------------------------------------------------------------------
sub open_evaluation_pipe
{
    my ( $counts_file, $l_max ) = @_;
    return () if ! &gjocodonlib::version( 'project_codon_usage_onto_axis' );

    my ( $rd, $wr, @eval_cmd );
    @eval_cmd  = 'project_codon_usage_onto_axis';
    push @eval_cmd, '-l', $l_max  if $l_max;
    push @eval_cmd, $counts_file;
    my $pid = open2( $rd, $wr, @eval_cmd );
    { my $old = select $wr; $| = 1; select $old; }  #  Autoflush the write pipe

    [ $pid, $rd, $wr ];
}

#-------------------------------------------------------------------------------
#      close_pipe2( $x_p_eval_pipe );
#-------------------------------------------------------------------------------
sub close_pipe2
{
    my ( $x_p_eval_pipe ) = @_;
    if ( $x_p_eval_pipe && ( ref( $x_p_eval_pipe ) eq 'ARRAY' ) && @$x_p_eval_pipe )
    {
        my ( $pid, $rd, $wr ) = @$x_p_eval_pipe;
        close $wr if $wr;
        close $rd if $rd;
        waitpid( $pid, 0 ) if $pid;
    }
}


#-------------------------------------------------------------------------------
#  Iteratively find a codon usage axis that maximizes the number of target
#  genes matching.
#
#      @axis_mode_estimates = find_axis( \%axis_parameters );
#
#  Parameters:
#
#      axis_name        =>  $axis_title        # D = 'Target'
#      genome_counts    => \@genome_counts     # required
#      genome_mode      =>  $genome_mode       # required
#      genome_title     =>  $genome_title      # D is none
#      log              => \*log               # D is none
#      match_p_value    =>  $match_p_value     # D =  0.10
#      max_iterations   =>  $max_iterations    # D =  2
#      max_keep         =>  $max_keep          # D =  0.2 * @genome_counts
#      max_mode_overlap =>  $max_mode_overlap  # D =  0.80
#      max_target_loss  =>  $max_target_loss   # D =  0.20
#      min_nonmodal     =>  $min_nonmodal      # D =  0.20 * @target_counts
#      min_targets      =>  $min_targets       # D = 20
#      min_x_value      =>  $min_x_value       # D =  0.50
#      mode_matches     => \%mode_matches      # required
#      mode_options     =>  $mode_options      # D = {};
#      mode_prefix      =>  $mode_prefix       # D = "$genome_title -- "
#      omit_counts      => \%omit_counts       # D = $mode_matches
#      omit_p_value     =>  $omit_p_value      # Log file information only
#      p_val_max_len    =>  $p_val_max_len     # D = none
#      reach_p_value    =>  $reach_p_value     # D = 0.5 * $match_p_value
#      target_counts    => \@target_counts     # required
#      x_p_eval_pipe    =>  $x_p_eval_pipe     # D is none
#
#-------------------------------------------------------------------------------
sub find_axis
{
    my $opts = shift || {};

    #  Required parameters:

    my $genome_counts = $opts->{ genome_counts };
    $genome_counts && ( ref($genome_counts) eq 'ARRAY' ) && @$genome_counts
        or return ();

    my $genome_mode = $opts->{ genome_mode };
    $genome_mode && ( ref($genome_mode) eq 'ARRAY' ) && @$genome_mode
        or return ();

    my $mode_matches = $opts->{ mode_matches };
    $mode_matches && ( ref($mode_matches) eq 'HASH' ) && %$mode_matches
        or return ();

    my $target_counts = $opts->{ target_counts };
    $target_counts && ( ref($target_counts) eq 'ARRAY' ) && @$target_counts
        or return ();

    #  Parameters that need a sanity check:

    my $omit_counts = $opts->{ omit_counts } || $mode_matches;
    $omit_counts && ( ref($omit_counts) eq 'HASH' ) && %$omit_counts
        or return ();

    my $mode_options = $opts->{ mode_options } || {};
    ref( $mode_options ) eq 'HASH' or $mode_options = {};

    #  Optional parameters:

    my $axis_uc          = $opts->{ axis_name }        || 'Target';
    my $genome_title     = $opts->{ genome_title };
    my $log              = $opts->{ log };
    my $match_p_value    = $opts->{ match_p_value }    ||  0.10;
    my $max_iterations   = $opts->{ max_iterations }   ||  2;
    my $max_keep         = $opts->{ max_keep }         ||  0.10 * @$genome_counts;
    my $max_mode_overlap = $opts->{ max_mode_overlap } ||  0.80;
    my $max_target_loss  = $opts->{ max_target_loss }  ||  0.20;
    my $min_nonmodal     = $opts->{ min_nonmodal }     ||  0.20 * @$target_counts;  # Does not work for everything
    my $min_targets      = $opts->{ min_targets }      || 20;
    my $min_x_value      = $opts->{ min_x_value }      ||  0.50;
    my $mode_prefix      = $opts->{ mode_prefix }      || ( $genome_title ? "$genome_title -- " : '' );
    my $omit_p_value     = $opts->{ omit_p_value };
    my $p_val_max_len    = $opts->{ p_val_max_len }    ||  0;
    my $reach_p_value    = $opts->{ reach_p_value }    ||  0.5 * $match_p_value;
    my $x_p_eval_pipe    = $opts->{ x_p_eval_pipe };

    #  Some preprocessing:

    my $n_gene = @$genome_counts;

    my $axis_lc = $axis_uc;
    substr( $axis_uc, 0, 1 ) =~ tr/a-z/A-Z/;
    substr( $axis_lc, 0, 1 ) =~ tr/A-Z/a-z/ if substr( $axis_lc, 1 ) !~ /A-Z/;

    my $n_orig_target    = @$target_counts;
    my %original_targets = map { $_ => 1 } @$target_counts;
    my %nonmodal_targets = map { $_ => 1 }
                           grep { ! $mode_matches->{ $_ } }
                           @$target_counts;

    #  Do the analysis:

    my @axis_modes = ();
    my $max_orig_target_match = -1;
    my $rollback = 0;

    my $all    = 0;
    my $done   = 0;
    my $n_iter = 0;
    while ( ! $done )
    {
        #  Remove genes matching mode

        my $n_cand = @$target_counts;
        if ( $log )
        {
            print  $log "$axis_uc codon frequencies, estimate $n_iter:\n";
            printf $log "%7d candidate $axis_lc representatives.\n", $n_cand;
        }

        if ( $n_cand < $min_targets )
        {
            if ( $log )
            {
                print $log "\n";
                print $log "Too few $axis_lc candidates to compute mode (< $min_targets).\n\n";
            }
            last;
        }

        my @target_nonmodal = grep { ! $omit_counts->{ $_ } } @$target_counts;
        my $n_survive = @target_nonmodal;
        my $min_needed = max( $min_targets, $min_nonmodal * $n_cand );
        if ( $n_survive < $min_needed ) { $all = 1; $done = 1 }
        else                            { @$target_counts = @target_nonmodal }

        if ( $log )
        {
            my $at_p_val = $omit_p_value ? " (P < $omit_p_value)" : '';
            printf $log "%7d candidate $axis_lc genes are distinct from mode$at_p_val.\n", $n_survive;
            printf $log "        %.1f%% of $axis_lc candidates are distinct from mode at this P-value.\n", 100*$n_survive/$n_cand;
            print  $log "    *** Computing mode from all candidates and terminating.\n" if $done;
            print  $log "\n";
        }

        #  Modal usage of the candidate target gene set:

        my $target_mode = modal_codon_usage( $target_counts, $mode_options );
        my $description = $mode_prefix
                        . "$axis_uc mode $n_iter"
                        . ( $all ? ' (including those matching the mode)' : '' );
        push @axis_modes, [ $target_mode, $description ];

        # Match of all genes to the new target estimate:

        my @match_target = map { $_->[1] >= $match_p_value ? $_->[0] : () }
                           cnts_and_p_values( $target_mode, $genome_counts, $p_val_max_len );
        my $n_match_target = @match_target;

        my $n_both = grep { $mode_matches->{ $_ } } @match_target;

        #  Match of all genes to the mode -> target axis.
        #  Each projection is [ $cnt, $x, $p ]

        my @projections = cnts_x_and_p( $x_p_eval_pipe, $genome_mode, $target_mode, $genome_counts, $p_val_max_len );

        #  Match to target axis with x >= 0 (if x < 0, then test is
        #  matching the mode).

        my @match_axis = grep { $mode_matches->{ $_->[0] } || ( $_->[1] >= 0 && $_->[2] >= $match_p_value ) }
                         @projections;
        my $n_match_axis = @match_axis;

        my $excess_overlap = ( ( $n_both > $max_mode_overlap * $n_match_target ) ? 0 : 0 );  ### This is inactive for now

        #  Count the original target candidates that survive.  We use this
        #  to detect systematic drift away from target genes.  If detected,
        #  we rollback the target mode to that based on the previous set.

        my $n_orig_target_match          = grep { $original_targets{ $_->[0] } } @match_axis;
        my $n_orig_target_nonmodal_match = grep { $nonmodal_targets{ $_->[0] } } @match_axis;
        $max_orig_target_match = $n_orig_target_nonmodal_match if $n_orig_target_nonmodal_match > $max_orig_target_match;

        my $target_match_loss = ( $n_orig_target_nonmodal_match < ( 1-$max_target_loss ) * $max_orig_target_match );

        $excess_overlap += 2 if ( $n_orig_target_nonmodal_match < ( 1-$max_mode_overlap ) * $n_orig_target_match );

        if ( $log )
        {
            my $prefix = ( $excess_overlap & 1 ) ? '*** Only' : '   ';
            my $pct_match_both = 100 * (1 - $n_both/$n_match_target);
            printf $log "%7d genes match $axis_lc estimate $n_iter (P >= $match_p_value).\n", $n_match_target;
            printf $log "%7d genes match both the mode and $axis_lc estimate.\n", $n_both;
            printf $log "    $prefix %.1f%% of genes matching the $axis_lc mode are distinct from\n", $pct_match_both;
            print  $log "           the overall mode.\n\n";

            my $pct_axis_match = 100*$n_match_axis/$n_gene;
            printf $log "%7d genes (%.1f%%) match the mode - $axis_lc axis (P >= $match_p_value).\n",  $n_match_axis, $pct_axis_match;
            printf $log "%7d of the original %d $axis_lc candidates match the axis.\n", $n_orig_target_match, $n_orig_target;
            printf $log "%7d of the original $axis_lc candidates match the axis but not mode.\n", $n_orig_target_nonmodal_match;

            if ( $excess_overlap & 2 )
            {
                my $pct_distinct = 100 * $n_orig_target_nonmodal_match/$n_orig_target_match;
                printf $log "    *** Only %.1f%% of the original $axis_lc candidates that match the\n", $pct_distinct;
                print  $log "           axis are distinct from the overall mode.\n";
            }
            if ( $target_match_loss )
            {
                printf $log "    *** Matches of original $axis_lc candidates has dropped more than %.1f%%.\n",
                             100 * $max_target_loss;
            }
            if ( ( $target_match_loss || $excess_overlap ) && ! $done )
            {
                print  $log "    *** Using first $axis_lc frequencies estimate.\n";
            }
            print  $log "\n";
        }

        $rollback = $excess_overlap || $target_match_loss;
        last if ( $n_iter >= $max_iterations ) || $done || $rollback;
        $n_iter++;

        # Limit by p-value (this is generally more relaxed than the match p-value):
        @projections = grep { $_->[2] >= $reach_p_value }  @projections;
        my $pass_p_val = @projections;

        # Limit by x-value (D = 0.5)
        @projections = grep { $_->[1] >= $min_x_value } @projections;
        my $pass_x_val = @projections;

        my $rank = 0;
        @projections = grep { ++$rank <= $max_keep }      # Limit number kept
                       sort { $b->[1] <=> $a->[1] }       # Highest x-value to lowest
                       @projections;
        my $pass_keep = @projections;

        @$target_counts = map { $_->[0] } @projections;

        if ( $log )
        {
            print  $log "New $axis_lc representatives:\n";
            printf $log "%7d genes pass P-value test (P >= $reach_p_value).\n", $pass_p_val;
            printf $log "%7d genes pass x-value test (x >= $min_x_value).\n", $pass_x_val;
            printf $log "%7d genes pass max keep test (n <= $max_keep).\n\n", $pass_keep;
        }
    }

    splice @axis_modes, 1  if ( @axis_modes > 1 ) && $rollback;

    @axis_modes;
}


#-------------------------------------------------------------------------------
#
#  @cnt_pval_pairs = cnts_and_p_values( $freq, \@cnts, $l_max );
#  @cnt_pval_pairs = cnts_and_p_values( $freq, \@cnts );
#
#-------------------------------------------------------------------------------
sub cnts_and_p_values
{
    my ( $freq, $cnts, $l_max ) = @_;
    $freq && ref( $freq ) eq 'ARRAY' or return ();
    $cnts && ref( $cnts ) eq 'ARRAY' or return ();
    my ( $chisqr, $df, $n );

    map { ( $chisqr, $df, $n ) = gjocodonlib::count_vs_freq_chi_sqr( $_, $freq );
          $chisqr *= $l_max / $n if $l_max && ( $n > $l_max );
          [ $_, $df ? gjostat::chisqr_prob( $chisqr, $df ) : 1 ]
        } @$cnts;
}

#-------------------------------------------------------------------------------
#
#  ( [ $cnt, $x, $p ], ... ) = cnts_x_and_p( $pipe, $freq1, $freq2, $cnts, $l_max );
#  ( [ $cnt, $x, $p ], ... ) = cnts_x_and_p( $pipe, $freq1, $freq2, $cnts );
#
#-------------------------------------------------------------------------------
sub cnts_x_and_p
{
    my ( $pipe, $freq1, $freq2, $cnts, $l_max ) = @_;
    $freq1 && ref( $freq1 ) eq 'ARRAY' or return ();
    $freq2 && ref( $freq2 ) eq 'ARRAY' or return ();
    $cnts  && ref( $cnts )  eq 'ARRAY' or return ();

    if ( $pipe )
    {
        my ( undef, $rd, $wr ) = @$pipe;
        gjocodonlib::report_frequencies( $wr, $freq1 );
        gjocodonlib::report_frequencies( $wr, $freq2 );
        my $x_p;
        map { chomp( $x_p = <$rd> ); [ $_, split( /\t/, $x_p ) ] } @$cnts;
    }
    else
    {
        my ( $proj, $x, $chisqr, $df, $len );
        map { ( $proj ) = gjocodonlib::project_on_freq_vector_by_chi_sqr_2( $freq1, $freq2, $_ );
              ( $x, $chisqr, $df, $len ) =  @$proj;
              $chisqr *= $l_max / $len if $l_max && ( $len > $l_max );
              [ $_, $x, ( $df ? gjostat::chisqr_prob( $chisqr, $df ) : 1 ) ]
            } @$cnts;
    }
}


#-------------------------------------------------------------------------------
#  $max = max( $n1, $n2 );
#-------------------------------------------------------------------------------
sub max { $_[0] >= $_[1] ? $_[0] : $_[1] }


1;
