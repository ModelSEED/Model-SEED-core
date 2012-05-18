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

package gjophylip;

#===============================================================================
#  A perl interface to programs in the PHYLIP program package:
#===============================================================================
#  proml:
#
#      @tree_likelihood_pairs = proml( \@alignment, \%options )
#      @tree_likelihood_pairs = proml( \@alignment,  %options )
#      @tree_likelihood_pairs = proml(              \%options )
#      @tree_likelihood_pairs = proml(               %options )
#
#  estimate_protein_site_rates -- Use proml to estimate site-specific rates of change
#
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree, \%proml_opts )
#
#  optimize_protein_coef_of_var:
#
#     ( $coef, $tree, $score ) = optimize_protein_coef_of_var( \@alignment, \%options )
#
#  dnadist:
#
#     $dists = dnadist( \@alignment, \%options )
#     $dists = dnadist(               %options )
#
#  dnadist and neighbor:
#
#     $tree = dnadist_neighbor( \@alignment, \%options )
#     $tree = dnadist_neighbor( \@alignment,  %options )
#     $tree = dnadist_neighbor(              \%options )
#     $tree = dnadist_neighbor(               %options )
#
#  protdist:
#
#     $distance_matrix = protdist( \@alignment, \%options )
#     $distance_matrix = protdist(               %options )
#
#  protdist and neighbor:
#
#     $tree = protdist_neighbor( \@alignment, \%options )
#     $tree = protdist_neighbor( \@alignment,  %options )
#     $tree = protdist_neighbor(              \%options )
#     $tree = protdist_neighbor(               %options )
#
#  neighbor:
#
#     $tree = neighbor( \@distances, \%options )
#     $tree = neighbor( \@distances,  %options )
#     $tree = neighbor(              \%options )
#     $tree = neighbor(               %options )
#
#  consense:
#
#     $consensus_with_boot_as_branch_len = consensus_tree(  @trees, \%options );
#     $consensus_with_boot_as_branch_len = consensus_tree( \@trees, \%options );
#     $consensus_with_boot_as_branch_len = consensus_tree(  @trees );
#     $consensus_with_boot_as_branch_len = consensus_tree( \@trees );
#
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree,  @trees, \%options );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree, \@trees, \%options );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree,  @trees );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree, \@trees );
#
#
#  Common options for PHYLIP programs:
#
#      alignment    => \@alignment     supply the alignment as an option
#      alpha        =>   float         alpha param of gamma distrib. (0.5 - inf)
#      categories   =>  $categories    category rates and site-specific rate categs
#      coef_of_var  =>   float         1/sqrt(alpha) of gamma distrib. (D = 0)
#      gamma_bins   =>   int           rates in approx. gamma distrib. (D = 5)
#      global       =>   bool          global rearrangements
#      invar_frac   =>   0 - 1         fraction of site that are invariant (D = 0)
#      jumble_seed  =>   odd_int       jumble random seed
#      model        =>   model         protein evolution model: JTT (D) | PMB | PAM
#      n_jumble     =>   int           number of order of addition jumbles
#      persistance  =>   float         persistance length of rate category (D = 0)
#      rate_hmm     =>  $rate_hmm      # not implimented
#      rearrange    => \@trees         rearrange user trees
#      slow         =>   bool          more accurate but slower search (D = 0)
#      user_lengths =>   bool          use user-supplied branch lengths (D = 0)
#      user_trees   => \@trees         use user-supplied trees
#      weights      =>  $site_weights  site-specific weights
#
#
#  Data types:
#
#     @alignment = ( [ id, def, seq ], [ id, def, seq ] ... )
#
#     $categories = [ [ cat1_rate, cat2_rate, ... ], $category_per_site_string ]
#
#     $rate_hmm = [ [ rate_1, prob_1 ], [ rate_2, prob2 ], ... ]
#
#     $weights = $weight_per_site_string
#
#
#  Common options for programming inferface:
#
#      keep_duplicates => bool         do not remove duplicate sequences [NOT IMPLIMENTED]
#      tmp          => directory       directory for tmp_dir
#      tmp_dir      => directory       directory for temporary files
#      tree_format  => format          format of output tree: overbeek | gjo | fig
#
#  Options that permit defining path or nonstandard name for program:
#
#      dnadist      => dnadist         just of dnadist_neighbor
#      program      => program         program name, possibly with full path
#      protdist     => protdist        just of protdist_neighbor
#      neighbor     => neighbor        dnadist_neighbor and protdist_neighbor
#
#
#  Auxilliary functions:
#
#  [ \@rates, $site_categs ] = read_categories( $categories_file )
#
#     $site_weights    = read_weights( $weights_file )
#
#     @distance_matrix = read_distances()        # D = outfile
#    \@distance_matrix = read_distances()
#     @distance_matrix = read_distances( $file )
#    \@distance_matrix = read_distances( $file )
#
#   ( \%id_index, \%bs_frac ) = read_consense_partitians()      # D = outfile
#   ( \%id_index, \%bs_frac ) = read_consense_partitians( $file )
#
#===============================================================================

use strict;
use SeedAware;
use gjonewicklib qw( gjonewick_to_overbeek
                     newick_is_unrooted
                     newick_relabel_nodes
                     newick_rescale_branches
                     newick_tree_length
                     overbeek_to_gjonewick
                     parse_newick_tree_str
                     strNewickTree
                     uproot_newick
                   );
use Data::Dumper;


#-------------------------------------------------------------------------------
#  proml -- A perl interface to the proml program
#
#     @tree_likelihood_pairs = proml( \@alignment, \%options )
#     @tree_likelihood_pairs = proml( \@alignment,  %options )
#     @tree_likelihood_pairs = proml( \%options )
#     @tree_likelihood_pairs = proml(  %options )
#
#          @alignment = ( [ id, seq ], [ id, seq ] ... )
#                       or
#                       ( [ id, def, seq ], [ id, def, seq ] ... )
#
#  options:
#
#    proml:
#      alignment    => \@alignment    supply the alignment as an option
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rate1, ... ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      gamma_bins   => int            number of rate categories used to approximate gamma (D=5)
#      global       => bool           global rearrangements
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      jumble_seed  => odd int        jumble random seed
#      model        => model          evolution model JTT (D) | PMB | PAM
#      n_jumble     => int            number of jumbles
#      persistance  => float          persistance length of rate category
#      rate_hmm     => rate_prob_pairs  general hidden markov model with 2 to 9 catefories
#      rearrange    => [ trees ]      rearrange user trees
#      slow         => bool           more accurate but slower search (D = 0)
#      user_lengths => bool           use supplied branch lengths
#      user_trees   => [ trees ]      user trees
#      weights      => site_weights
#
#    other:
#      definitions  => bool           include definition in sequence label
#      keep_duplicates => bool        do not remove duplicate sequences [NOT IMPLIMENTED]
#      no_ids       => bool           leave the sequence id out of the sequence label
#      program      => program        allows fully defined path
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#
#-------------------------------------------------------------------------------

sub proml
{
    my $align;
    $align = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    #  Collect the options in a hash, and canonicalize their keys:

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $align ||= $options{ alignment } || $options{ align };

    my ( $align2, $id, $local_id ) = &process_protein_alignment( $align );

    if ( ! $align2 )
    {
        print STDERR "    gjophylip::proml requires an alignment.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process proml options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $categories   = $options{ categorie };  #  The 's' is lost in canonicalizing keys
    if ( $categories )
    {
        ( $categories = &process_categories( $categories ) )
            or print STDERR "    gjophylip::proml bad categories option value.\n"
            and return ();
    }

    my $coef_of_var  = $options{ coefofvar }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "gjophylip::proml coef_of_var option value must be >= 0\n";
        return ();
    }

    my $no_ids      = $options{ noid }       || 0;
    my $definitions = $options{ definition } || $no_ids; # No id requires definition
    if ( $definitions )
    {
        my %new_id = map { $_->[0] => ( ! length $_->[1] ? $_->[0] : $no_ids ? $_->[1] : "$_->[0] $_->[1]" ) }
                     map { [ $_->[0], @$_ == 3 && defined $_->[1] ? $_->[1] : '' ] }
                     @$align;
        foreach ( keys %$id ) { $id->{ $_ } = $new_id{ $id->{ $_ } } }
    }

    my $gamma_bins = int( $options{ gammabin } || ( $coef_of_var ? 5 : 2 ) );
    if ( ( $gamma_bins < 2 )  || ( $gamma_bins > 9 ) )
    {
        print STDERR "gjophylip::proml gamma_bins option value must be > 1 and <= 9\n";
        return ();
    }

    my $global = $options{ global } || 0;

    my $invar_frac = $options{ invarfrac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "gjophylip::proml invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $n_jumble = int( $options{ njumble } || ( $options{ jumbleseed } ? 1 : 0) );
    if ( $n_jumble < 0 )
    {
        print STDERR "gjophylip::proml n_jumble option value must be >= 0\n";
        return ();
    }

    my $jumble_seed  = int( $options{ jumbleseed } || 4 * int( 499999999 * rand() ) + 1 );
    if ( ( $jumble_seed <= 0)  || ( $jumble_seed % 2 != 1 ) )
    {
        print STDERR "gjophylip::proml jumble_seed option value must be an odd number > 0\n";
        return ();
    }

    my $model = &process_protein_model( \%options );

    my $persistance = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "gjophylip::proml persistance option value must be > 1\n";
        return ();
    }

    my $rate_hmm = $options{ ratehmm };
    if ( $rate_hmm )
    {
        ( $rate_hmm = &process_rate_hmm( $rate_hmm ) )
            or print STDERR "    gjophylip::proml bad rate_hmm value\n"
            and return ();
    }

    my $rearrange = $options{ rearrange };

    my $slow = $options{ slow };

    my $user_lengths = $options{ userlength };

    my $user_trees = $options{ usertree } || $rearrange;
    if ( $user_trees )
    {
        if ( ( ref( $user_trees ) ne 'ARRAY' ) || ( ! @$user_trees ) )
        {
            $user_trees = undef;                      # No trees
        }
        elsif ( ref( $user_trees->[0] ) ne 'ARRAY' )  # First element not tree
        {
            print STDERR "gjophylip::proml user_trees or rearrange option value must be reference to list of trees\n";
            return ();
        }
    }

    my $weights = $options{ weight };

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Options that are not proml options per se:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $program = SeedAware::executable_for( $options{ proml } || $options{ program } || 'proml' )
        or print STDERR "Could not locate executable file for 'proml'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    my $tree_format = process_tree_format( \%options );

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Prepare data:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my @user_trees = ();
    if ( $user_trees && @$user_trees )
    {
        if ( gjonewicklib::is_overbeek_tree( @$user_trees[0] ) )
        {
            @user_trees = map { gjonewicklib::overbeek_to_gjonewick( $_ ) }
                          @$user_trees;
        }
        else
        {
            @user_trees = map { gjonewicklib::copy_newick_tree( $_ ) }
                          @$user_trees;
        }

        # Relabel and make sure trees are unrooted:

        @user_trees = map { gjonewicklib::newick_is_unrooted( $_ )
                               ? $_
                               : gjonewicklib::uproot_newick( $_ )
                          }
                      map { gjonewicklib::newick_relabel_nodes( $_, $local_id ); $_ }
                      @user_trees;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Write the files and run the program:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my ( $trees, $likelihoods ) = run_proml( align        =>  $align2,
                                             categories   =>  $categories,
                                             coef_of_var  =>  $coef_of_var,
                                             gamma_bins   =>  $gamma_bins,
                                             global       =>  $global,
                                             invar_frac   =>  $invar_frac,
                                             jumble_seed  =>  $jumble_seed,
                                             model        =>  $model,
                                             n_jumble     =>  $n_jumble,
                                             program      =>  $program,
                                             persistance  =>  $persistance,
                                             rate_hmm     =>  $rate_hmm,
                                             rearrange    =>  $rearrange,
                                             slow         =>  $slow,
                                             user_lengths =>  $user_lengths,
                                             user_trees   => \@user_trees,
                                             weights      =>  $weights,
                                           );

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    #  Fix the tree labels:

    my @trees = map { gjonewicklib::newick_relabel_nodes( $_, $id ) }
                @$trees;

    #  Fix the tree format, if necessary:

    if ( $tree_format =~ m/overbeek/i )
    {
        @trees = map { gjonewicklib::gjonewick_to_overbeek( $_ ) } @trees;
    }

    #  Merge into a list of tree-likelihood pairs:

    return map { [ $_, shift @$likelihoods ] } @trees;
}


#-------------------------------------------------------------------------------
#  A local routine to run proml
#-------------------------------------------------------------------------------
sub run_proml
{
    my %data = @_;

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto

    &write_seq_infile( @{ $data{align} } )
          or print STDERR "gjophylip::run_proml: Could not write infile\n"
             and return ();

    open( PROML, ">proml_cmd" )
          or print STDERR "gjophylip::run_proml: Could not open command file\n"
             and return ();

    if ( $data{categories} )
    {
        &write_categories( $data{categories}->[1] )
              or print STDERR "gjophylip::run_proml: Could not write categories\n"
                 and return ();
        print PROML "C\n",
                    scalar @{$data{categories}->[0]}, "\n",
                    join( ' ', @{ $data{categories}->[0] } ), "\n";
    }

    if ( $data{invar_frac} || $data{coef_of_var} || $data{rate_hmm} )
    {
        print PROML "R\n";
        print PROML "R\n" if $data{invar_frac} || $data{rate_hmm};
        print PROML "R\n" if $data{rate_hmm};
        print PROML "A\n", "$data{persistance}\n" if $data{persistance};

    }

    print PROML "G\n" if $data{global};

    print PROML "J\n", "$data{jumble_seed}\n", "$data{n_jumble}\n" if $data{n_jumble};

    print PROML "P\n"    if $data{model} =~ m/PMB/i;
    print PROML "P\nP\n" if $data{model} =~ m/PAM/i;

    if ( @{$data{user_trees}} )
    {
        &write_intree( @{$data{user_trees}} )
              or print STDERR "gjophylip::run_proml: Could not write intree\n"
                 and return ();
        print PROML "U\n";
        print PROML "V\n" if $data{rearrange} || $data{global};
        print PROML "L\n" if $data{user_lengths} && ! $data{rearrange} && ! $data{global};
    }
    elsif ( $data{slow} )  # Slow and user trees are mutually exclusive
    {
        print PROML "S\n";
    }

    if ( $data{weights} )
    {
        &write_weights( $data{weights} )
              or print STDERR "gjophylip::run_proml: Could not write weights\n"
                 and return ();
        print PROML "W\n";
    }

    #  We have identified all the options; indicate this with 'Y':

    print PROML "Y\n";

    #  Becuase of the options interface, some values still must be supplied:

    if ( $data{invar_frac} || $data{coef_of_var} )
    {
        if ( $data{invar_frac} )
        {
            if ( $data{coef_of_var} ) { $data{gamma_bins}++ if $data{gamma_bins} < 9 }
            else                      { $data{gamma_bins} = 2 }
        }
        print PROML "$data{coef_of_var}\n";
        print PROML "$data{gamma_bins}\n";
        print PROML "$data{invar_frac}\n"    if $data{invar_frac};
    }
    elsif ( $data{rate_hmm} )
    {
        my @hmm = @{ $data{rate_hmm} };
        print PROML scalar @hmm, "\n";
        primt PROML join( ' ', map { sprintf( "%.6f", $_->[0] ) } @hmm ), "\n";
        primt PROML join( ' ', map { sprintf( "%.6f", $_->[1] ) } @hmm ), "\n";
    }

    if ( @{$data{user_trees}} )
    {
        print PROML "13\n";     #  Random number seed of unknown use
    }

    close PROML;

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Run the program
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $program   = $data{ program } || $data{ proml } || 'proml';
    my $redirects = { stdin  => 'proml_cmd',
                      stdout => 'proml_out',   # Gets deleted with tmp dir
                      stderr => 'proml_err'    # Gets deleted with tmp dir
                    };
    SeedAware::system_with_redirect( $program, $redirects )
        and print STDERR "gjophylip::run_proml: Could not run $program.\n"
             and return undef;

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Gather the results
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my @likelihoods = &read_likelihoods();

    my @trees = gjonewicklib::read_newick_trees( 'outtree' );
    @trees or print STDERR "gjophylip::run_proml: Could not read proml outtree file\n"
              and return ();

    return ( \@trees, \@likelihoods );
}


#-------------------------------------------------------------------------------
#  estimate_protein_site_rates -- Use proml to estimate site-specific rates of change
#
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree,  %proml_opts )
#     ( $categories, $weights ) = estimate_protein_site_rates( \@align, $tree, \%proml_opts )
#
#          $categories = [ [ $rate1, ... ], $site_categories ];
#
#          $alignment = [ [ id, def, seq ], ... ]
#                       or
#                       [ [ id, seq ], ... ]
#
#  proml_opts is list of key value pairs, or reference to a hash
#-------------------------------------------------------------------------------

sub estimate_protein_site_rates
{
    my ( $align, $tree, @proml_opts ) = @_;

    #  Clean-up the alignment, and make local ids that are compatible with
    #  the PHYLIP programs:

    my ( $id, $local_id );
    ( $align, $id, $local_id ) = &process_protein_alignment( $align );

    if ( ! $align )
    {
        print STDERR "    gjophylip::estimate_protein_site_rates requires an alignment.\n";
        return ();
    }
    
    my @align = @$align;

    #  Make the tree a gjonewick tree, uproot it, and change to the local ids.

   if ( gjonewicklib::is_overbeek_tree( $tree ) )
    {
        $tree = gjonewicklib::overbeek_to_gjonewick( $tree );
    }
    else
    {
        $tree = gjonewicklib::copy_newick_tree( $tree );
    }

    $tree = gjonewicklib::uproot_newick( $tree ) if ! gjonewicklib::newick_is_unrooted( $tree );

    gjonewicklib::newick_relabel_nodes( $tree, $local_id );

    #  The minimum rate will be 1/2 change per total tree branch length.
    #  This needs to be checked for proml.  The intent is that he optimal
    #  rate for a site with one amino acid change is twice this value.

    my $kmin = 1 / ( gjonewicklib::newick_tree_length( $tree ) || 1 );

    #  Generate "rate variation" by rescaling the supplied tree.  We could use a
    #  finer grain estimator, then categorize the inferred values.  This might
    #  work slightly better (this is what DNArates currently does).

    my $f = exp( log( 2 ) / 1 );                        # Interval of 2
    my @rates = map { $kmin * $f**$_ } ( 0 .. 16 );     # kmin .. 65000 * kmin in 17 bins
    my @cat_vals = ( 1 .. 17 );
    my @trees;
    my $rate;
    foreach $rate ( @rates )
    {
        my $tr = gjonewicklib::copy_newick_tree( $tree );
        gjonewicklib::newick_rescale_branches( $tr, $rate ); # Rescales in place
        push @trees, $tr;
    }

    #  Adjust (a copy of) the proml opts:

    my %proml_opts = ( ref( $proml_opts[0] ) eq 'HASH' ) ? %{ $proml_opts[0] } : @proml_opts;

    $proml_opts{ user_lengths } =   1;
    $proml_opts{ user_trees   } = \@trees;
    $proml_opts{ tree_format  } =  'gjonewick';

    delete $proml_opts{ alpha       } if exists $proml_opts{ alpha       };
    delete $proml_opts{ categories  } if exists $proml_opts{ categories  };
    delete $proml_opts{ coef_of_var } if exists $proml_opts{ coef_of_var };
    delete $proml_opts{ gamma_bins  } if exists $proml_opts{ gamma_bins  };
    delete $proml_opts{ invar_frac  } if exists $proml_opts{ invar_frac  };
    delete $proml_opts{ jumble_seed } if exists $proml_opts{ jumble_seed };
    delete $proml_opts{ n_jumble    } if exists $proml_opts{ n_jumble    };
    delete $proml_opts{ rate_hmm    } if exists $proml_opts{ rate_hmm    };
    delete $proml_opts{ rearrange   } if exists $proml_opts{ rearrange   };

    #  Work throught the sites, finding their optimal rates/categories:

    my @categories;
    my @weights;
    my $imax = length( $align[0]->[-1] );
    for ( my $i = 0; $i < $imax; $i++ )
    {
        my $inform = 0;
        my @align2 = map { my $c = substr( $_->[-1], $i, 1 );
                           $inform++ if ( $c =~ m/[ACDEFGHIKLMNPQRSTVWY]/i );
                           [ $_->[0], $c ]
                         }
                     @$align;

        #  Only analyze the rate if there are 4 or more informative sequences:

        if ( $inform >= 4 )
        {
            my @results = proml( \@align2, \%proml_opts );

            my ( $best ) = sort { $b->[1] <=> $a->[1] }
                           map  { [ $_, @{ shift @results }[1] ] }  # get the likelihoods
                           @cat_vals;

#           printf STDERR "%6d  %2d => %12.4f\n", $i+1, @$best; ## DEBUG ##
            push @categories, $best->[0];
            push @weights,    1;
        }
        else
        {
            push @categories, 9;
            push @weights,    0;
        }
    }

    #  Find the minimum category value to appear:

    my ( $mincat ) = sort { $a <=> $b } @categories;
    my $adjust = $mincat - 1;

    @categories = map { min( $_ - $adjust, 9 ) } @categories;
    @rates = @rates[ $adjust .. ( $adjust+8 ) ];

    #  Return category and weight data:

    ( [ \@rates, join( '', @categories ) ], join( '', @weights ) )
}


#===============================================================================
#  optimize_protein_coef_of_var -- Find optimal tree and coeficient of variation.
#
#     ( $coef, $tree, $score ) = optimize_protein_coef_of_var( \@alignment, \%options )
#
#  Options are same as proml, plus:
#
#      max     => max_coef    #  Largest value of search range (D = 2)
#      step    => step_size   #  Step size for intial grid search (D = 0.32)
#      verbose => boolean     #  Print progress to STDERR (D = 0)
#
#===============================================================================
sub optimize_protein_coef_of_var
{
    my ( $align, $opts ) = @_;
    $align && ref $align eq 'ARRAY' && @$align > 3 && $align->[0] && ref $align->[0] eq 'ARRAY'
        or return ();

    my $max_coef = $opts->{ max }     || $opts->{ maximum } || 2;
    my $step     = $opts->{ step }    || $opts->{ step0 }   || 0.32;
    my $verbose  = $opts->{ verbose } || 0;

    my @coefs;
    for ( my $c = 0; $c <= $max_coef; $c += $step ) { push @coefs, $c }
    my %tree_score;
    while ( 1 )
    {
        #  Evaluate any values without a score (and tree)
        foreach my $coef ( grep { ! $tree_score{ $_ } } @coefs )
        {
            $opts->{ coef_of_var } = $coef;
            ( $tree_score{ $coef } ) = gjophylip::proml( $align, $opts );
            print STDERR "Coef = $coef, LnLikelihood = $tree_score{$coef}->[1]\n" if $verbose;
        }

        #  Sort highest score to lowest score
        @coefs = sort { $tree_score{$b}->[1] <=> $tree_score{$a}->[1] } @coefs;
        last if $step <= 0.011;                  # Done if reached desired resolution

        splice @coefs, 3;                        # Keep best 3
        $step *= 0.5;                            # Go to half the step size
        @coefs = sort { $a <=> $b } @coefs;      # Put in numerical order
        push @coefs, $coefs[0]+$step, $coefs[2]-$step;  # Add intermediate coefs
    }

    ( $coefs[0], @{ $tree_score{$coefs[0]} } );  # coef_of_var, tree, lnlikelihood
}


#===============================================================================
#  dnadist -- A perl interface to the dnadist program
#
#     $dists = dnadist( \@alignment, \%options )
#     $dists = dnadist(  %options )
#
#           @alignment = ( [ id, seq ], [ id, seq ] ... )
#                        or
#                        ( [ id, def, seq ], [ id, def, seq ] ... )
#
#  Options:
#
#    dnadist:
#      alignment    => \@alignment    supply the alignment as an option
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rates ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      model        => model          evolution model JTT (D) | PMB | PAM
#      rate_hmm     => rate_prob_pairs  does not exist in current dnadist
#      weights      => site_weights
#
#    other:
#      keep_duplicates => bool        do not remove duplicate sequences [NOT IMPLIMENTED]
#      dnadist      => dnadist        allows fully defined path
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#===============================================================================

sub dnadist
{
    my $align;
    $align = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids.
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $align ||= $options{ alignment } || $options{ align };

    my ( $id, $local_id );
    ( $align, $id, $local_id ) = &process_dna_alignment( $align );

    if ( ! $align )
    {
        print STDERR "    gjophylip::dnadist requires an alignment.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process dnadist options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $categories   = $options{ categorie };  #  The 's' is lost in canonicalizing keys
    if ( $categories )
    {
        ( $categories = &process_categories( $categories ) )
            or print STDERR "    gjophylip::dnadist bad categories option value.\n"
            and return ();
    }

    my $coef_of_var  = $options{ coefofvar }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "gjophylip::dnadist coef_of_var option value must be >= 0\n";
        return ();
    }

    my $frequencies = $options{ frequencie };
    if ( $frequencies && ( ref( $frequencies ) ne 'ARRAY' || ( @$frequencies != 4 ) ) )
    {
        print STDERR "gjophylip::dnadist frequences must be [ f(A), f(C), f(G), f(T) ]\n";
        return ();
    }

    my $invar_frac = $options{ invarfrac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "gjophylip::dnadist invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $model = &process_dna_model( \%options );

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "gjophylip::dnadist persistance option value must be > 1\n";
        return ();
    }

    #  Does not exist in current dnadist program
    #
    # my $rate_hmm = $options{ ratehmm };
    # if ( $rate_hmm )
    # {
    #     ( $rate_hmm = &process_rate_hmm( $rate_hmm ) )
    #         or print STDERR "    gjophylip::proml bad rate_hmm value\n"
    #         and return ();
    # }

    my $tt_param = $options{ transitiontransversion } || $options{ ttparam };
    if ( $tt_param && ( $tt_param <= 0 ) )
    {
        print STDERR "gjophylip::dnadist tt_param option value must be > 0\n";
        return ();
    }

    my $weights = $options{ weight };


    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Options that are not dnadist options per se:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $dnadist = SeedAware::executable_for( $options{ dnadist } || 'dnadist' )
        or print STDERR "Could not locate executable file for 'dnadist'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Write the files and run the program:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my $distances = run_dnadist( align       =>  $align,
                                 categories  =>  $categories,
                                 coef_of_var =>  $coef_of_var,
                                 program     =>  $dnadist,
                                 frequencies =>  $frequencies,
                                 invar_frac  =>  $invar_frac,
                                 model       =>  $model,
                                 persistance =>  $persistance,
                                 # rate_hmm  =>  $rate_hmm,
                                 tt_param    =>  $tt_param,
                                 weights     =>  $weights,
                               );

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    return $distances;
}


#-------------------------------------------------------------------------------
#  A local routine to run dnadist
#-------------------------------------------------------------------------------
sub run_dnadist
{
    my %data = @_;

    unlink 'outfile' if -f 'outfile';  # Just checking

    &write_seq_infile( @{$data{align}} )
          or print STDERR "gjophylip::run_dnadist: Could write infile\n"
             and return undef;

    open( DNAD, ">dnadist_cmd" )
          or print STDERR "gjophylip::run_dnadist: Could not open command file for $data{dnadist}\n"
             and return undef;

    #  Some sanity checks (dnadist does not like to get something that it
    #  does not expect):

    if ( $data{model} ne 'F84' )
    {
        $data{frequencies} = undef;
    }

    if ( $data{model} =~ m/LogDet/i
      || $data{model} =~ m/identity/i
       )
    {
        $data{categories}  = undef;
        $data{coef_of_var} = undef;
        $data{invar_frac}  = undef;
    }


    #  Start writing options for dnadist (order matters):

    #  Cycle through to correct model (F84 is default):

    print DNAD "D\n"          if $data{model} =~ m/Kimura/i;
    print DNAD "D\nD\n"       if $data{model} =~ m/JC/i;
    print DNAD "D\nD\nD\n"    if $data{model} =~ m/LogDet/i;
    print DNAD "D\nD\nD\nD\n" if $data{model} =~ m/identity/i;

    if ( $data{categories} )
    {
        &write_categories( $data{categories}->[1] )
              or print STDERR "gjophylip::run_dnadist: Could not write categories\n"
                 and return undef;
        print DNAD "C\n",
                    scalar @{$data{categories}->[0]}, "\n",
                    join( ' ', map { sprintf( "%.6f", $_ ) } @{ $data{categories}->[0] } ), "\n";
    }
    elsif ( $data{invar_frac} || $data{coef_of_var} )
    {
        print DNAD "G\n";
        print DNAD "G\n" if $data{invar_frac};
        # print DNAD "A\n", "$data{persistance}\n" if $data{persistance};
    }

    if ( $data{tt_param} && ( $data{model} =~ m/Kimura/i
                           || $data{model} =~ m/Kimura/i
                            )
       )
    {
        print  DNAD "T\n";
        printf DNAD "%.6f\n", $data{tt_param};
    }

    if ( $data{weights} )
    {
        &write_weights( $data{weights} )
            or print STDERR "gjophylip::run_dnadist: Could not write weights\n"
               and return undef;
        print DNAD "W\n";
    }

    #  We have identified all the options; indicate this with 'Y':

    print DNAD "Y\n";

    #  Becuase of the options interface, some values still must be supplied:

    if ( $data{invar_frac} || $data{coef_of_var} )
    {
        print DNAD "$data{coef_of_var}\n";
        print DNAD "$data{invar_frac}\n" if $data{invar_frac};
    }

    close DNAD;

    #---------------------------------------------------------------------------
    #  Run the program
    #---------------------------------------------------------------------------

    my $program   = $data{ program } || $data{ dnadist } || 'dnadist';
    my $redirects = { stdin  => 'dnadist_cmd',
                      stdout => 'dnadist_out',   # Gets deleted with tmp dir
                      stderr => 'dnadist_err'    # Gets deleted with tmp dir
                    };
    SeedAware::system_with_redirect( $program, $redirects )
        and print STDERR "gjophylip::run_dnadist: Could not run $program.\n"
             and return undef;

    #---------------------------------------------------------------------------
    #  Gather the results
    #---------------------------------------------------------------------------

    my $distances = read_distances();
    $distances or print STDERR "gjophylip::run_dnadist: Could not read 'outfile'\n"
               and return undef;

    return $distances;
}


#===============================================================================
#  dnadist_neighbor -- A perl interface to the dnadist and neighbor programs
#
#     $tree = dnadist_neighbor( \@alignment, \%options )
#     $tree = dnadist_neighbor( \@alignment,  %options )
#     $tree = dnadist_neighbor( \%options )
#     $tree = dnadist_neighbor(  %options )
#
#           @alignment = ( [ id, seq ], [ id, seq ] ... )
#                        or
#                        ( [ id, def, seq ], [ id, def, seq ] ... )
#
#  Options:
#
#    dnadist:
#      alignment    => \@alignment    supply the alignment as an option
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rates ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      model        => model          evolution model JTT (D) | PMB | PAM
#      rate_hmm     => rate_prob_pairs  does not exist in current dnadist
#      weights      => site_weights
#
#    neighbor:
#      jumble_seed  => odd_int        jumble random seed
#
#    other:
#      definitions  => bool           include definition in sequence label
#      dnadist      => dnadist        allows fully defined path
#      keep_duplicates => bool        do not remove duplicate sequences [NOT IMPLIMENTED]
#      neighbor     => neighbor       allows fully defined path
#      no_ids       => bool           leave the sequence id out of the sequence label
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#===============================================================================

sub dnadist_neighbor
{
    my $align;
    $align = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids.
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $align ||= $options{ alignment } || $options{ align };

    my ( $align2, $id, $local_id ) = &process_dna_alignment( $align );

    if ( ! $align2 )
    {
        print STDERR "    gjophylip::dnadist_neighbor requires an alignment.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process dnadist_neighbor options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $categories   = $options{ categorie };  #  The 's' is lost in canonicalizing keys
    if ( $categories )
    {
        ( $categories = &process_categories( $categories ) )
            or print STDERR "    gjophylip::dnadist_neighbor bad categories option value.\n"
            and return ();
    }

    my $coef_of_var  = $options{ coefofvar }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "gjophylip::dnadist_neighbor coef_of_var option value must be >= 0\n";
        return ();
    }

    my $no_ids      = $options{ noid }       || 0;
    my $definitions = $options{ definition } || $no_ids; # No id requires definition
    if ( $definitions )
    {
        my %new_id = map { $_->[0] => ( ! length $_->[1] ? $_->[0] : $no_ids ? $_->[1] : "$_->[0] $_->[1]" ) }
                     map { [ $_->[0], @$_ == 3 && defined $_->[1] ? $_->[1] : '' ] }
                     @$align;
        foreach ( keys %$id ) { $id->{ $_ } = $new_id{ $id->{ $_ } } }
    }

    my $frequencies = $options{ frequencie };
    if ( $frequencies && ( ref( $frequencies ) ne 'ARRAY' || ( @$frequencies != 4 ) ) )
    {
        print STDERR "gjophylip::dnadist_neighbor frequences must be [ f(A), f(C), f(G), f(T) ]\n";
        return ();
    }

    my $invar_frac = $options{ invarfrac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "gjophylip::dnadist_neighbor invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $jumble_seed = int( $options{ jumbleseed } ) || 0;
    if ( $jumble_seed && ( ( $jumble_seed < 0)  || ( $jumble_seed % 2 != 1 ) ) )
    {
        print STDERR "gjophylip::dnadist_neighbor jumble_seed option value must be an odd number > 0\n";
        return ();
    }

    my $model = &process_dna_model( \%options );

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "gjophylip::dnadist_neighbor persistance option value must be > 1\n";
        return ();
    }

    #  Does not exist in current dnadist program
    #
    # my $rate_hmm = $options{ ratehmm };
    # if ( $rate_hmm )
    # {
    #     ( $rate_hmm = &process_rate_hmm( $rate_hmm ) )
    #         or print STDERR "    gjophylip::proml bad rate_hmm value\n"
    #         and return ();
    # }

    my $tt_param = $options{ transitiontransversion } || $options{ ttparam };
    if ( $tt_param && ( $tt_param <= 0 ) )
    {
        print STDERR "gjophylip::dnadist_neighbor tt_param option value must be > 0\n";
        return ();
    }

    my $weights = $options{ weight };


    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Options that are not dnadist_neighbor options per se:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $dnadist = SeedAware::executable_for( $options{ dnadist } || 'dnadist' )
        or print STDERR "Could not locate executable file for 'dnadist'.\n"
            and return undef;

    my $neighbor = SeedAware::executable_for( $options{ neighbor } || 'neighbor' )
        or print STDERR "Could not locate executable file for 'neighbor'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    my $tree_format = process_tree_format( \%options );

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Write the files and run the program:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my $distances = run_dnadist( align       =>  $align2,
                                 categories  =>  $categories,
                                 coef_of_var =>  $coef_of_var,
                                 program     =>  $dnadist,
                                 frequencies =>  $frequencies,
                                 invar_frac  =>  $invar_frac,
                                 model       =>  $model,
                                 persistance =>  $persistance,
                                 # rate_hmm  =>  $rate_hmm,
                                 tt_param    =>  $tt_param,
                                 weights     =>  $weights,
                               );

    my $tree = undef;
    if ( $distances )
    {
        $tree = run_neighbor( distances   => $distances,
                              jumble_seed => $jumble_seed,
                              program     => $neighbor
                            );
    }

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    if ( $tree )
    {
        #  Returned trees have our labels:

        gjonewicklib::newick_relabel_nodes( $tree, $id );

        if ( $tree_format =~ m/overbeek/i )
        {
            $tree = gjonewicklib::gjonewick_to_overbeek( $tree );
        }
    }

    return $tree;
}


#===============================================================================
#  protdist -- A perl interface for the PHYLIP protdist program:
#
#     \@distance_matrix = protdist( \@alignment, \%options )
#     \@distance_matrix = protdist( \@alignment,  %options )
#     \@distance_matrix = protdist( \%options )
#     \@distance_matrix = protdist(  %options )
#
#           @alignment = ( [ id, seq ], [ id, seq ] ... )
#                        or
#                        ( [ id, def, seq ], [ id, def, seq ] ... )
#
#           @distance_matrix = ( [ id1, dist11, dist12, dist13, ... ],
#                                [ id2, dist21, dist22, dist14, ... ],
#                               ...
#                              )
#
#  Options:
#
#    protdist
#      alignment    => \@alignment    supply the alignment as an option
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rates ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      model        => model          evolution model JTT (D) | PMB | PAM
#      persistance  => float          persistance length of rate category
#      rate_hmm     => [ [ rates ], [ probabilies ] ]
#      weights      => site_weights
#
#    other:
#      protdist     => protdist       allows fully defined path
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#===============================================================================
sub protdist
{
    my $align;
    $align = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids.
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $align ||= $options{ alignment } || $options{ align };

    my ( $id, $local_id );
    ( $align, $id, $local_id ) = &process_protein_alignment( $align );

    if ( ! $align )
    {
        print STDERR "    gjophylip::protdist requires an alignment.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process protdist options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $categories   = $options{ categorie };  #  The 's' is lost in canonicalizing keys
    if ( $categories )
    {
        ( $categories = &process_categories( $categories ) )
            or print STDERR "    gjophylip::protdist bad categories option value.\n"
            and return ();
    }

    my $coef_of_var  = $options{ coefofvar }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "gjophylip::protdist coef_of_var option value must be >= 0\n";
        return undef;
    }

    my $invar_frac   = $options{ invarfrac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "gjophylip::protdist invar_frac option value must be >= 0 and < 1\n";
        return undef;
    }

    my $model = &process_protein_model( \%options );

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "gjophylip::protdist persistance option value must be > 1\n";
        return undef;
    }

    #  Does not exist in current protdist
    #
    # my $rate_hmm = $options{ ratehmm };
    # if ( $rate_hmm )
    # {
    #     ( $rate_hmm = &process_rate_hmm( $rate_hmm ) )
    #         or print STDERR "    gjophylip::proml bad rate_hmm value\n"
    #         and return ();
    # }

    my $weights      = $options{ weight };


    #---------------------------------------------------------------------------
    #  Options that are not protdist options per se:
    #---------------------------------------------------------------------------

    my $protdist = SeedAware::executable_for( $options{ protdist } || 'protdist' )
        or print STDERR "Could not locate executable file for 'protdist'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my $distances = run_protdist( align       =>  $align,
                                  categories  =>  $categories,
                                  coef_of_var =>  $coef_of_var,
                                  invar_frac  =>  $invar_frac,
                                  model       =>  $model,
                                  persistance =>  $persistance,
                                  program     =>  $protdist,
                                # rate_hmm    =>  $rate_hmm,
                                  weights     =>  $weights,
                                );

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    #  Fix the taxon labels:

    foreach ( @$distances ) { $_->[0] = $id->{ $_->[0] } }

    return $distances;
}


#-------------------------------------------------------------------------------
#  A local routine to run protdist
#-------------------------------------------------------------------------------
sub run_protdist
{
    my %data = @_;

    unlink 'outfile' if -f 'outfile';  # Just checking

    &write_seq_infile( @{$data{align}} )
          or print STDERR "gjophylip::run_protdist: Could write infile\n"
             and return undef;

    open( PROTD, ">protdist_cmd" )
          or print STDERR "gjophylip::run_protdist: Could not open command file for $data{protdist}\n"
             and return undef;

    #  Start writing options for protdist:

    if ( $data{categories} )
    {
        &write_categories( $data{categories}->[1] )
              or print STDERR "gjophylip::run_protdist: Could not write categories\n"
                 and return undef;
        print PROTD "C\n",
                    scalar @{$data{categories}->[0]}, "\n",
                    join( ' ', map { sprintf( "%.6f", $_ ) } @{ $data{categories}->[0] } ), "\n";
    }

    if ( $data{invar_frac} || $data{coef_of_var} )
    {
        print PROTD "G\n";
        print PROTD "G\n" if $data{invar_frac};
        print PROTD "A\n", "$data{persistance}\n" if $data{persistance};
    }

    print PROTD "P\n"       if $data{model} =~ m/PMB/i;
    print PROTD "P\nP\n"    if $data{model} =~ m/PAM/i;
    print PROTD "P\nP\nP\n" if $data{model} =~ m/Kimura/i;

    if ( $data{weights} )
    {
        &write_weights( $data{weights} )
            or print STDERR "gjophylip::run_protdist: Could not write weights\n"
               and return undef;
        print PROTD "W\n";
    }

    #  We have identified all the options; indicate this with 'Y':

    print PROTD "Y\n";

    #  Becuase of the options interface, some values still must be supplied:

    if ( $data{invar_frac} || $data{coef_of_var} )
    {
        print PROTD "$data{coef_of_var}\n";
        print PROTD "$data{invar_frac}\n" if $data{invar_frac};
    }

    close PROTD;

    #---------------------------------------------------------------------------
    #  Run the program
    #---------------------------------------------------------------------------

    my $program   = $data{ program } || $data{ protdist } || 'protdist';
    my $redirects = { stdin  => 'protdist_cmd',
                      stdout => 'protdist_out',   # Gets deleted with tmp dir
                      stderr => 'protdist_err'    # Gets deleted with tmp dir
                    };
    SeedAware::system_with_redirect( $program, $redirects )
        and print STDERR "gjophylip::run_protdist: Could not run $program.\n"
             and return undef;

    #---------------------------------------------------------------------------
    #  Gather the results
    #---------------------------------------------------------------------------

    my $distances = read_distances();
    $distances or print STDERR "gjophylip::run_protdist: Could not read 'outfile'\n"
               and return undef;

    return $distances;
}


#===============================================================================
#  protdist_neighbor -- A perl interface to the protdist and neighbor programs
#
#     $tree = protdist_neighbor( \@alignment, \%options )
#     $tree = protdist_neighbor( \@alignment,  %options )
#     $tree = protdist_neighbor( \%options )
#     $tree = protdist_neighbor(  %options )
#
#           @alignment = ( [ id, seq ], [ id, seq ] ... )
#                        or
#                        ( [ id, def, seq ], [ id, def, seq ] ... )
#
#  Options:
#
#    protdist:
#      alignment    => \@alignment    supply the alignment as an option
#      alpha        => float          alpha parameter of gamma distribution (0.5 - inf)
#      categories   => [ [ rates ], site_categories ]
#      coef_of_var  => float          1/sqrt(alpha) for gamma distribution (D = 0)
#      invar_frac   => 0 - 1          fraction of site that are invariant
#      model        => model          evolution model JTT (D) | PMB | PAM
#      rate_hmm     => rate_prob_pairs  does not exist in current protdist
#      weights      => site_weights
#
#    neighbor:
#      jumble_seed  => odd_int        jumble random seed
#
#    other:
#      definitions  => bool           include definition in sequence label
#      keep_duplicates => bool        do not remove duplicate sequences [NOT IMPLIMENTED]
#      no_ids       => bool           leave the sequence id out of the sequence label
#      protdist     => protdist       allows fully defined path
#      neighbor     => neighbor       allows fully defined path
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#===============================================================================

sub protdist_neighbor
{
    my $align;
    $align = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids.
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $align ||= $options{ alignment } || $options{ align };

    my ( $align2, $id, $local_id ) = &process_protein_alignment( $align );

    if ( ! $align2 )
    {
        print STDERR "    gjophylip::protdist_neighbor requires an alignment.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process protdist_neighbor options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $categories   = $options{ categorie };  #  The 's' is lost in canonicalizing keys
    if ( $categories )
    {
        ( $categories = &process_categories( $categories ) )
            or print STDERR "    gjophylip::protdist_neighbor bad categories option value.\n"
            and return ();
    }

    my $coef_of_var  = $options{ coefofvar }
                  || ( $options{ alpha } && ( $options{ alpha } > 0) && ( 1 / sqrt( $options{ alpha } ) ) )
                  ||  0;
    if ( $coef_of_var < 0 )
    {
        print STDERR "gjophylip::protdist_neighbor coef_of_var option value must be >= 0\n";
        return ();
    }

    my $no_ids      = $options{ noid }       || 0;
    my $definitions = $options{ definition } || $no_ids; # No id requires definition
    if ( $definitions )
    {
        my %new_id = map { $_->[0] => ( ! length $_->[1] ? $_->[0] : $no_ids ? $_->[1] : "$_->[0] $_->[1]" ) }
                     map { [ $_->[0], @$_ == 3 && defined $_->[1] ? $_->[1] : '' ] }
                     @$align;
        foreach ( keys %$id ) { $id->{ $_ } = $new_id{ $id->{ $_ } } }
    }

    my $invar_frac   = $options{ invarfrac } || 0;
    if ( $invar_frac && ( $invar_frac < 0 || $invar_frac >= 1 ) )
    {
        print STDERR "gjophylip::protdist_neighbor invar_frac option value must be >= 0 and < 1\n";
        return ();
    }

    my $jumble_seed = int( $options{ jumbleseed } || 0 );
    if ( $jumble_seed && ( ( $jumble_seed < 0)  || ( $jumble_seed % 2 != 1 ) ) )
    {
        print STDERR "gjophylip::protdist_neighbor jumble_seed option value must be an odd number > 0\n";
        return ();
    }

    my $model = &process_protein_model( \%options );

    my $persistance  = $options{ persistance } || 0;
    if ( $persistance && ( $persistance <= 1 ) )
    {
        print STDERR "gjophylip::protdist_neighbor persistance option value must be > 1\n";
        return ();
    }

    #  Does not exist in current protdist program
    #
    # my $rate_hmm = $options{ ratehmm };
    # if ( $rate_hmm )
    # {
    #     ( $rate_hmm = &process_rate_hmm( $rate_hmm ) )
    #         or print STDERR "    gjophylip::proml bad rate_hmm value\n"
    #         and return ();
    # }

    my $weights      = $options{ weight };


    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Options that are not protdist_neighbor options per se:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $protdist = SeedAware::executable_for( $options{ protdist } || 'protdist' )
        or print STDERR "Could not locate executable file for 'protdist'.\n"
            and return undef;

    my $neighbor = SeedAware::executable_for( $options{ neighbor } || 'neighbor' )
        or print STDERR "Could not locate executable file for 'neighbor'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    my $tree_format = process_tree_format( \%options );

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Write the files and run the program:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my $distances = run_protdist( align       =>  $align2,
                                  categories  =>  $categories,
                                  coef_of_var =>  $coef_of_var,
                                  invar_frac  =>  $invar_frac,
                                  model       =>  $model,
                                  persistance =>  $persistance,
                                  program     =>  $protdist,
                                # rate_hmm    =>  $rate_hmm,
                                  weights     =>  $weights,
                                );

    my $tree = undef;
    if ( $distances )
    {
        $tree = run_neighbor( distances   => $distances,
                              jumble_seed => $jumble_seed,
                              program     => $neighbor
                            );
    }

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    if ( $tree )
    {
        #  Returned trees have our labels:

        gjonewicklib::newick_relabel_nodes( $tree, $id );

        if ( $tree_format =~ m/overbeek/i )
        {
            $tree = gjonewicklib::gjonewick_to_overbeek( $tree );
        }
    }

    return $tree;
}


#===============================================================================
#  neighbor -- A perl interface to the neighbor program
#
#     $tree = neighbor( \@distances, \%options )
#     $tree = neighbor( \@distances,  %options )
#     $tree = neighbor( \%options )
#     $tree = neighbor(  %options )
#
#           @distances = ( [ id1, dist11, dist12, ... ],
#                          [ id2, dist21, dist22, ... ],
#                          ...
#                        )
#
#  Options:
#
#    neighbor:
#      jumble_seed  => odd_int        jumble random seed
#      upgma        => bool           use UPGMA
#
#    other:
#      neighbor     => neighbor       allows fully defined path
#      program      => neighbor       allows fully defined path
#      tmp          => directory      directory for tmp_dir
#      tmp_dir      => directory      directory for temporary files
#      tree_format  => overbeek | gjo | fig  format of output tree
#
#  tmp_dir is created and deleted unless its name is supplied, and it already
#  exists.
#===============================================================================
sub neighbor
{
    my $distances;
    $distances = shift @_ if ( ref( $_[0] ) eq 'ARRAY' );

    my %options;
    if ( $_[0] )
    {
        my %opts = ( ref( $_[0]) eq 'HASH' ) ? %{ $_[0] } : @_;
        %options = map { canonical_key( $_ ) => $opts{ $_ } } keys %opts;
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Clean up a local copy of the alignment.  Assign local ids.
    #  Alignment can also be an option:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $distances ||= $options{ distance } || $options{ dist };

    my ( $id, $local_id );
    ( $distances, $id, $local_id ) = &process_distance_matrix( $distances );

    if ( ! $distances )
    {
        print STDERR "    gjophylip::neighbor requires a distance matrix.\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Process neighbor options:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $jumble_seed = int( $options{ jumbleseed } || 0 );
    if ( $jumble_seed && ( ( $jumble_seed < 0)  || ( $jumble_seed % 2 != 1 ) ) )
    {
        print STDERR "gjophylip::neighbor jumble_seed option value must be an odd number > 0\n";
        return ();
    }

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Options that are not neighbor options per se:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $program = SeedAware::executable_for( $options{ neighbor } || $options{ program } || 'neighbor' )
        or print STDERR "Could not locate executable file for 'neighbor'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( \%options );
    $tmp_dir or return ();

    my $tree_format = process_tree_format( \%options );

    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    #  Write the files and run the program:
    #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my $tree = run_neighbor( distances   => $distances,
                             jumble_seed => $jumble_seed,
                             program     => $program,
                             upgma       => $options{ upgma },
                           );

    #  We are done, go back to the original directory:

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    if ( $tree )
    {
        #  Returned trees have our labels:

        gjonewicklib::newick_relabel_nodes( $tree, $id );

        if ( $tree_format =~ m/overbeek/i )
        {
            $tree = gjonewicklib::gjonewick_to_overbeek( $tree );
        }
    }

    return $tree;
}


#-------------------------------------------------------------------------------
#  A local routine to run neighbor
#-------------------------------------------------------------------------------
sub run_neighbor
{
    my %data = @_;

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto

    write_dist_infile( $data{distances} )
          or print STDERR "gjophylip::run_neighbor: Could not write distance infile\n"
             and return undef;

    open( NEIGH, ">neighbor_cmd" )
          or print STDERR "gjophylip::run_neighbor: Could not open neighbor command file\n"
             and return undef;
    print NEIGH "J\n", "$data{jumble_seed}\n" if $data{jumble_seed};
    print NEIGH "N\n" if $data{upgma};
    print NEIGH "Y\n";
    close NEIGH;

    #---------------------------------------------------------------------------
    #  Run the program
    #---------------------------------------------------------------------------

    my $program   = $data{ program } || $data{ neighbor } || 'neighbor';
    my $redirects = { stdin  => 'neighbor_cmd',
                      stdout => 'neighbpr_out',   # Gets deleted with tmp dir
                      stderr => 'neighbpr_err'    # Gets deleted with tmp dir
                    };
    SeedAware::system_with_redirect( $program, $redirects )
        and print STDERR "gjophylip::run_neighbor: Could not run $program.\n"
             and return undef;

    #---------------------------------------------------------------------------
    #  Gather the results
    #---------------------------------------------------------------------------

    my ( $tree ) = gjonewicklib::read_newick_tree( 'outtree' );

    $tree or print STDERR "gjophylip::run_neighbor: Could not read neighbor outtree file\n";

    return $tree || undef;
}


#-------------------------------------------------------------------------------
#  Consensus tree:
#
#     $consensus_with_boot_as_branch_len = consensus_tree(  @trees, \%options );
#     $consensus_with_boot_as_branch_len = consensus_tree( \@trees, \%options );
#     $consensus_with_boot_as_branch_len = consensus_tree(  @trees );
#     $consensus_with_boot_as_branch_len = consensus_tree( \@trees );
#
#  Option keys:
#
#     consense => program    # Define alternative name or path to executable
#     savetmp  => boolean    # Do not delete temporary directory or files.
#     tmpdir   => directory  # Directory for temporary files. If directory
#                            #     exists, temporary files are not deleted.
#     tmp      => directory  # Directory for tmpdir
#
#-------------------------------------------------------------------------------
sub consensus_tree 
{
    my $options = ( ( @_ > 1 ) && ( ref( $_[-1] ) eq 'HASH' ) ) ? pop @_ : {};

    return undef if ( ! @_ ) || ( ref( $_[0] ) ne 'ARRAY' );

    my @trees = ( @_ > 1 ) ? @_ : @{ $_[0] };
    my $n_tree = @trees;
    my $tip = 'tip000001';
    my %tips = map { $_ => $tip++ } gjonewicklib::newick_tip_list( $trees[0] );

    # Make a copy of trees with clean labels

    my @trees2 = map { gjonewicklib::newick_relabel_tips( gjonewicklib::copy_newick_tree( $_ ), \%tips ) }
                 @trees;

    my $program = SeedAware::executable_for( $options->{ consense } || $options->{ program } || 'consense' )
        or print STDERR "Could not locate executable file for 'consense'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( $options );
    $tmp_dir or return ();

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;
    chomp $cwd;
    chdir $tmp_dir;

    my ( $tree )= run_consense( { trees => \@trees2, consense => $program } );

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system "/bin/rm -r '$tmp_dir'" if ! $save_tmp;

    return undef if ! $tree;

    #  run_consense() fixes the root and branch lengths. All we need to do is
    #  fix the taxon labels and return the tree:

    gjonewicklib::newick_relabel_tips( $tree, { reverse %tips } );
}


#-------------------------------------------------------------------------------
#  Consensus tree:
#
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree,  @trees, \%options );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree, \@trees, \%options );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree,  @trees );
#     $tree_with_labeled_nodes = bootstrap_label_nodes( $tree, \@trees );
#
#  Option keys:
#
#     consense => program    # Define alternative name or path to executable
#     midpoint => boolean    # Midpoint root reference tree before labeling
#     savetmp  => boolean    # Do not delete temporary directory or files.
#     tmpdir   => directory  # Directory for temporary files. If directory
#                            #     exists, temporary files are not deleted.
#     tmp      => directory  # Directory for tmpdir (D = SEED tmp or /tmp)
#
#-------------------------------------------------------------------------------
sub bootstrap_label_nodes 
{
    my $reftree = shift;
    my $options = ( ( @_ > 1 ) && ( ref( $_[-1] ) eq 'HASH' ) ) ? pop @_ : {};

    return undef if ( ! @_ ) || ( ref( $_[0] ) ne 'ARRAY' );

    my @trees  = ( @_ > 1 ) ? @_ : @{ $_[0] };
    my $n_tree = @trees;
    my $tip    = 'tip000001';
    my %tips   = map { $_ => $tip++ } gjonewicklib::newick_tip_list( $trees[0] );

    # Make a copy of trees with clean labels

    my @trees2 = map { gjonewicklib::newick_relabel_tips( gjonewicklib::copy_newick_tree( $_ ), \%tips ) }
                 @trees;

    my $program = SeedAware::executable_for( $options->{ consense } || $options->{ program } || 'consense' )
        or print STDERR "Could not locate executable file for 'consense'.\n"
            and return undef;

    my ( $tmp_dir, $save_tmp ) = SeedAware::temporary_directory( $options );
    $tmp_dir or return ();

    #---------------------------------------------------------------------------
    #  Write the files and run the program:
    #---------------------------------------------------------------------------

    my $cwd = $ENV{ cwd } || `pwd`;

    chomp $cwd;
    chdir $tmp_dir;
    my $data = { trees => \@trees2, consense => $program };
    my ( undef, $id_index, $bs_frac ) = run_consense( $data );

    chdir $cwd;

    #  Delete the temporary directory unless it already existed:

    system( '/bin/rm', '-r', $tmp_dir ) if ! $save_tmp;

    $id_index && $bs_frac or return undef;

    #  We need to map taxon labels and then traverse the tree, putting the
    #  bootstrap fractions as internal node labels:

    my %id_index_2 = map { $_ => $id_index->{ $tips{ $_ } } }
                     keys %tips;

    my $format = $n_tree > 100 ? '%.3f' : '%.2f';

    my ( $set1, $set2, $frac );
    my %bs_frac_2 = map { ( $set1 = $_    ) =~ tr/.*/01/;
                          ( $set2 = $set1 ) =~ tr/01/10/;
                          $frac = sprintf( $format, $bs_frac->{ $_ } );
                          ( $set1 => $frac, $set2 => $frac )
                        }
                    keys %$bs_frac;

    $reftree = gjonewicklib::copy_newick_tree( $reftree );   #  Copy reference tree
    $reftree = gjonewicklib::reroot_newick_to_midpoint_w( $reftree ) if $options->{ midpoint };

    label_nodes_with_bs( $reftree, \%id_index_2, \%bs_frac_2 );
    gjonewicklib::set_newick_lbl( $reftree, undef );  # Root node label

    $reftree;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Label tree nodes with their bootstrap proportion. Work from the tips to
#  root. Return the "tip_set" representing the set of tips below the node.
#
#    $tip_set = label_nodes_with_bs( $reftree, \%id_index, $bs_frac );
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub label_nodes_with_bs
{
    my ( $node, $id_index, $bs_frac ) = @_;

    my $tip_set = '0' x keys %$id_index;

    my @dl = gjonewicklib::newick_desc_list( $node );
    if ( @dl )
    {
        foreach ( @dl )
        {
            $tip_set |= label_nodes_with_bs( $_, $id_index, $bs_frac );
        }
        gjonewicklib::set_newick_lbl( $node, $bs_frac->{ $tip_set } || '0.00' );
    }
    else
    {
        my $index = $id_index->{ gjonewicklib::newick_lbl( $node ) };
        substr( $tip_set, $index, 1 ) = "1";
    }

    $tip_set;
}


#-------------------------------------------------------------------------------
#  Internal routine to run consense:
#
#     ( $tree, \%id_index, \%boot_frac ) = run_consense( \%data )
#
#  Data:
#
#     consense =>  $program_name_or_path  # D = consense
#     trees    => \@trees
#
#-------------------------------------------------------------------------------
sub run_consense
{
    my $data = shift;
    $data and ref( $data ) eq 'HASH'
          or print STDERR "gjophylip::run_consense: Called without data hash.\n"
             and return undef;

    $data->{trees} && ref( $data->{trees} ) eq 'ARRAY'
          or print STDERR "gjophylip::run_consense: Array of trees not provided.\n"
             and return undef;

    my $n_tree = @{ $data->{trees} }
          or print STDERR "gjophylip::run_consense: No trees.\n"
             and return undef;

    write_intree_no_count( @{ $data->{trees} } );

    unlink 'outfile' if -f 'outfile';  # Just checking
    unlink 'outtree' if -f 'outtree';  # ditto


    #  No command options, so just echo Y to exectute

    my $program   = $data->{ program } || $data->{ consense } || 'consense';
    my $redirects = { stdout => 'consense_out',   # Gets deleted with tmp dir
                      stderr => 'consense_err'    # Gets deleted with tmp dir
                    };
    my $consenseFH = SeedAware::write_to_pipe_with_redirect( $program, $redirects )
        or return ();
    print $consenseFH "Y\n";
    close $consenseFH;

    my $tree = gjonewicklib::read_newick_tree( 'outtree' );

    $tree or print STDERR "gjophylip::run_consense: Could not read consense outtree file.\n"
        and return ();

    $tree = gjonewicklib::uproot_newick( $tree );
    $tree = gjonewicklib::newick_modify_branches( $tree, \&rescale_bootstrap, [ 1/$n_tree ] );

    my ( $id_index, $bs_frac ) = read_consense_partitians();

    $id_index && $bs_frac
        or print STDERR "gjophylip::run_consense: Could not read consense outfile.\n"
            and return ();

    return ( $tree, $id_index, $bs_frac );
}


sub rescale_bootstrap
{
    my( $x, $scale ) = @_;
    return undef if ! defined $x;
    $x *= $scale;
    $x  = 1 if $x > 1;  #  This deals with an artifact in some PHYLIP consensus trees
    return $x;
}


#-------------------------------------------------------------------------------
#  Utility functions:
#-------------------------------------------------------------------------------
#  Allow variations of option keys including uppercase, underscores and
#  terminal 's':
#
#      $key = canonical_key( $key );
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub canonical_key
{
    my $key = lc shift;
    $key =~ s/_//g;
    $key =~ s/s$//;  #  This is dangerous if an s is part of a word!
    return $key;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  min
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub min { $_[0] < $_[1] ? $_[0] : $_[1] }


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  pack_by_mask
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub pack_by_mask
{
    my ( $seq, $mask ) = @_;
    $seq &= $mask;         #  Mask the string
    $seq  =~ tr/\000//d;   #  Compress out X'00'
    $seq;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_dna_alignment
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_dna_alignment
{
    my ( $align ) = @_;

    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) || ( @$align < 2 ) )
    {
        print STDERR "gjophylip function called without a required alignment.\n";
        return ();
    }

    #  Make a clean copy of the alignment.  Id is always first, seq is always last.

    my ( $seq, $id, %id, %local_id );
    my $local_id = 'seq0000000';
    my @align = map { $id = $_->[0];
                      $local_id++;
                      $id{ $local_id } = $id;
                      $local_id{ $id } = $local_id;
                      $seq =  $_->[-1];
                      $seq =~ s/[EFIJLOPQXZ]/N/gi;  # Bad letters go to N
                      $seq =~ s/[^A-Z-]/-/gi;       # Anything else becomes -
                      [ $local_id, '', $seq ]
                    }
                @$align;

    #  Should probably add a length check

    return ( \@align, \%id, \%local_id );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_protein_alignment
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_protein_alignment
{
    my ( $align ) = @_;

    if ( ! $align || ( ref( $align ) ne 'ARRAY' ) || ( @$align < 2 ) )
    {
        print STDERR "gjophylip function called without a required alignment.\n";
        return ();
    }

    #  Make a clean copy of the alignment.  Id is always first, seq is always last.

    my ( $seq, $id, %id, %local_id );
    my $local_id = 'seq0000000';
    my @align = map { $id = $_->[0];
                      $local_id++;
                      $id{ $local_id } = $id;
                      $local_id{ $id } = $local_id;
                      $seq =  $_->[-1];
                      $seq =~ s/[BJOUZ]/X/gi;  # Bad letters go to X
                      $seq =~ s/[^A-Z-]/-/gi;  # Anything else becomes -
                      [ $local_id, '', $seq ]
                    }
                @$align;

    #  Should probably add a length check

    return ( \@align, \%id, \%local_id );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_categories
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_categories
{
    my ( $categories ) = @_;

    # Verify the list:

    if ( ref( $categories ) ne 'ARRAY'
      || ( @$categories != 2 )
      || ( ref( $categories->[0] ) ne 'ARRAY' )
      || ( @{ $categories->[0] } < 2 )
      || ( @{ $categories->[0] } > 9 )
       )
    {
        print STDERR "gjophylip categories option value must be [ [ rate1, ... ], site_cats ]\n";
        print STDERR "    with 2 - 9 rate categories\n";
        return undef;
    }

    #  Rate values cannot have many decimal places or proml can't read them:

    @{ $categories->[0] } = map { sprintf( "%.6f", $_ ) } @{ $categories->[0] };

    return $categories;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_distance_matrix
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_distance_matrix
{
    my ( $distances ) = @_;

    if ( ! $distances || ( ref( $distances ) ne 'ARRAY' ) || ( @$distances < 2 ) )
    {
        print STDERR "gjophylip function called without required distances.\n";
        return ();
    }

    #  Make a clean copy of the distances with a local id.

    my ( $id, %id, %local_id );
    my $local_id = 'tax0000000';
    my @distances = map { $id = $_->[0];
                          $local_id++;
                          $id{ $local_id } = $id;
                          $local_id{ $id } = $local_id;
                          [ $local_id, @$_[ 1 .. $#{@$_} ] ]
                        }
                    @$distances;

    #  Should probably add a length check

    return ( \@distances, \%id, \%local_id );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_dna_model
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_dna_model
{
    my ( $options ) = @_;

    $options && ref $options eq 'HASH' && $options->{ model }
        or return 'F84';

    #  Allow a ridiculous list of synonyms:

    my $model = ( $options->{ model } =~ m/F84/i         ) ? 'F84'
              : ( $options->{ model } =~ m/Churchill/i   ) ? 'F84'
              : ( $options->{ model } =~ m/Felsenstein/i ) ? 'F84'
              : ( $options->{ model } =~ m/Hasegawa/i    ) ? 'F84'
              : ( $options->{ model } =~ m/Kishino/i     ) ? 'F84'

              : ( $options->{ model } =~ m/Kimura/i      ) ? 'Kimura'

              : ( $options->{ model } =~ m/JC/i          ) ? 'JC'
              : ( $options->{ model } =~ m/Jukes/i       ) ? 'JC'
              : ( $options->{ model } =~ m/Cantor/i      ) ? 'JC'

              : ( $options->{ model } =~ m/LogDet/i      ) ? 'LogDet'
              : ( $options->{ model } =~ m/Barry/i       ) ? 'LogDet'
              : ( $options->{ model } =~ m/Hartigan/i    ) ? 'LogDet'
              : ( $options->{ model } =~ m/Lake/i        ) ? 'LogDet'
              : ( $options->{ model } =~ m/Lockhart/i    ) ? 'LogDet'
              : ( $options->{ model } =~ m/Steel/i       ) ? 'LogDet'

              : ( $options->{ model } =~ m/identity/i    ) ? 'identity'
              : ( $options->{ model } =~ m/similarity/i  ) ? 'identity'

              :                                              'F84';

    return $model;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_protein_model
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_protein_model
{
    my ( $options ) = @_;

    $options && ref $options eq 'HASH' && $options->{ model }
        or return 'JTT';

    #  Allow a ridiculous list of synonyms:

    my $model = ( $options->{ model } =~ m/PAM/i        ) ? 'PAM'
              : ( $options->{ model } =~ m/Dayhoff/i    ) ? 'PAM'
              : ( $options->{ model } =~ m/Kosiol/i     ) ? 'PAM'
              : ( $options->{ model } =~ m/Goldman/i    ) ? 'PAM'
              : ( $options->{ model } =~ m/DCMut/i      ) ? 'PAM'

              : ( $options->{ model } =~ m/PMB/i        ) ? 'PMB'
              : ( $options->{ model } =~ m/Henikoff/i   ) ? 'PMB'
              : ( $options->{ model } =~ m/Smith/i      ) ? 'PMB'
              : ( $options->{ model } =~ m/Tillier/i    ) ? 'PMB'
              : ( $options->{ model } =~ m/Veerassamy/i ) ? 'PMB'

              : ( $options->{ model } =~ m/JTT/i        ) ? 'JTT'
              : ( $options->{ model } =~ m/Jones/i      ) ? 'JTT'
              : ( $options->{ model } =~ m/Taylor/i     ) ? 'JTT'
              : ( $options->{ model } =~ m/Thornton/i   ) ? 'JTT'

              :                                             'JTT';

    return $model;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_tree_format( \%options )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_tree_format
{
    my ( $options ) = @_;

    $options && ref $options eq 'HASH' or return 'overbeek';

    #  Allow a ridiculous list of synonyms:

    return ! $options->{ treeformat }                 ? 'overbeek'  :
             $options->{ treeformat } =~ m/overbeek/i ? 'overbeek'  :
             $options->{ treeformat } =~ m/gjo/i      ? 'gjonewick' :
             $options->{ treeformat } =~ m/fig/i      ? 'fig'       :
                                                        'overbeek'; # Default
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  process_rate_hmm
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub process_rate_hmm
{
    my ( $rate_hmm ) = @_;

    # Verify the list:

    if ( ( ref( $rate_hmm ) ne 'ARRAY' )
      || ( @$rate_hmm < 2 )
      || ( @$rate_hmm > 9 )
       )
    {
        print STDERR "gjophylip rate_hmm must be a reference to 2-9 rate-probability pairs\n";
        return undef;
    }

    #  Verify the elements of the list:

    my $total = 0;
    my @rate_hmm2 = grep { ( ref( $_ ) eq 'ARRAY' )
                        && ( @$_ == 2 )            # [ rate, probability ]
                        && ( $_->[0] >= 0 )        # Rate can be zero
                        && ( $_->[1]  = 0 )        # Probability cannot be zero
                        && ( $total += $_->[1] )   # Cumumlative probability
                         }
                     @$rate_hmm;

    #  If anything was lost, there was an error:

    ( @rate_hmm2 == @$rate_hmm )
        or print STDERR "gjophylip rate_hmm must be a reference to rate-probability pairs\n"
        and return undef;

    #  Normalize the probabilities:

    foreach ( @rate_hmm2 ) { $_->[1] /= $total }

    return \@rate_hmm2;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_categories( $categories )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_categories
{
    my $categories = shift;
    open( CATEGORIES, '>categories' ) or return 0;
    print CATEGORIES "$categories\n";
    close( CATEGORIES );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_dist_infile( $distances )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_dist_infile
{
    my $distances = shift;
    ( ref( $distances ) eq 'ARRAY' ) && @$distances or return 0;
    my $ntaxa = @$distances;
    my $format = "%-10s" . (" %11.6f" x $ntaxa) . "\n";
    open( DISTANCES, '>infile' ) or return 0;
    print DISTANCES "$ntaxa\n";
    foreach ( @$distances ) { printf DISTANCES $format, @$_ }
    close( DISTANCES );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_intree( @trees )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_intree
{
    open( INTREE, '>intree' ) or return 0;
    print INTREE scalar @_, "\n";
    foreach ( @_ ) { print INTREE gjonewicklib::strNewickTree( $_ ), "\n" }
    close( INTREE );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_intree_no_count
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_intree_no_count
{
    open( INTREE, '>intree' ) or return 0;
    foreach ( @_ ) { print INTREE gjonewicklib::strNewickTree( $_ ), "\n" }
    close( INTREE );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_seq_infile(  @alignment )
#  write_seq_infile( \@alignment )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_seq_infile
{
    @_ && $_[0] && ref $_[0] eq 'ARRAY' && @{$_[0]} && defined $_[0]->[0]
        or return undef;
    my @seq = ref $_[0]->[0] eq 'ARRAY' ? @{ $_[0] } : @_;

    open( INFILE, '>infile' ) or return 0;
    printf INFILE "%d %d\n", scalar @_, length( $seq[0]->[-1] );
    foreach ( @seq ) { printf INFILE "%-10s  %s\n", @$_[0, -1] }
    close( INFILE );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  write_weights( $weights )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub write_weights
{
    my $weights = shift;
    open( WEIGHTS, '>weights' ) or return 0;
    print WEIGHTS "$weights\n";
    close( WEIGHTS );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  read_categories
#
#  Expect category rates on first line, followed by site categories.
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub read_categories
{
    $_[0] && -f $_[0]
        or print STDERR "read_categories() requires a file name.\n"
            and return undef;
    open( CATEGS, '<$_[0]' )
        or print STDERR "Could not open categories file $_[0]\n"
        and return undef;
    my @rates  = split " ", <CATEGS>;
    my $categs = join( '', map { chomp; s/ \s+//g; $_ }
                            <CATEGS>
                      );
    close( CATEGS );
    return [ \@rates, $categs ];
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  read_weights
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub read_weights
{
    $_[0] && -f $_[0]
        or print STDERR "read_weights() requires a file name.\n"
            and return undef;
    open( WEIGHTS, '<$_[0]' )
        or print STDERR "Could not open weights file $_[0]\n"
            and return undef;
    my $weights = join( '', map { chomp; s/ \s+//g; $_ } <WEIGHTS> );
    close( WEIGHTS );

    return $weights;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  read_distances
#
#      @distance_matrix = read_distances()        # D = outfile
#     \@distance_matrix = read_distances()
#      @distance_matrix = read_distances( $file )
#     \@distance_matrix = read_distances( $file )
#
#      @distance_matrix = ( [ id1, dist11, dist12, dist13, ... ],
#                           [ id2, dist21, dist22, dist14, ... ],
#                           ...
#                         )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub read_distances
{
    my $file = $_[0] && -f $_[0] ? $_[0] : 'outfile';

    my @distances;
    open( DISTS, "<$file" ) or return ();
    my $line;
    defined( $line = <DISTS> ) or return ();
    my ( $ndist ) = $line =~ m/(\d+)/;

    for ( my $i = 0; $i < $ndist; $i++ )
    {
        defined( $line = <DISTS> ) or return ();
        chomp $line;
        my ( @row ) = split " ", $line;
        while ( @row <= $ndist )
        {
            defined( $line = <DISTS> ) or return ();
            chomp $line;
            push @row, split " ", $line;
        }

        push @distances, \@row;
    }
    close( DISTS );

    wantarray ? @distances : \@distances;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  read_likelihoods
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub read_likelihoods
{
    my $file = $_[0] && -f $_[0] ? $_[0] : 'outfile';

    open( OUTFILE, "<$file" ) or return ();
    my @likelihoods = map  { chomp; s/.* //; $_ }
                      grep { /^Ln Likelihood/ }
                      <OUTFILE>;
    close( OUTFILE );

    wantarray ? @likelihoods : \@likelihoods;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#    ( \%id_index, \%bs_frac ) = read_consense_partitians()
#    ( \%id_index, \%bs_frac ) = read_consense_partitians( $file )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub read_consense_partitians
{
    my $file = defined $_[0] && -f $_[0] ? $_[0] : 'outfile';
    open( OUTFILE, "<$file" ) or return ();

    local $_;
    while ( defined( $_ = <OUTFILE> ) && ! /^Species in order/ ) {}
    $_ or close( OUTFILE ) and return ();

    #  Hash with zero-based offset of each taxon in the partitian set strings

    my %id_index;
    while ( defined( $_ = <OUTFILE> ) && ! /^Sets included in the consensus tree/ )
    {
        chomp;
        my ( $n, $id ) = split;
        $id_index{ $id } = $n - 1 if $n && $id;
    }
    $_ or close( OUTFILE ) and return ();

    while ( defined( $_ = <OUTFILE> ) && ! /How many times out of \s*\d\S*\d/ ) {}
    $_ or close( OUTFILE ) and return ();
    my( $ttl ) = /How many times out of \s*(\d\S*\d)/;
    $ttl or close( OUTFILE ) and return ();

    my %bs_frac;
    while ( defined( $_ = <OUTFILE> ) && ! /^Extended majority rule/ )
    {
        next if /^Set/;
        chomp;
        my ( $set, $cnt ) = m/^(\S.*\S)\s+(\d+\.\d+)\s*$/;
        $set && $cnt or next;
        $set =~ s/\s+//g;
        $bs_frac{ $set } = $cnt / $ttl;
    }
    $_ or close( OUTFILE ) and return ();

    close( OUTFILE );

    return ( \%id_index, \%bs_frac );
}


1;
