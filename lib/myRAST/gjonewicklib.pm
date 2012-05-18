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

package gjonewicklib;

#===============================================================================
#  perl functions for dealing with trees
#
#  Usage:  use gjonewicklib
#
#===============================================================================
#  Tree data structures:
#===============================================================================
#
#  Elements in newick text file are:
#
#     [c1] ( desc_1, desc_2, ... ) [c2] label [c3] : [c4] x [c5]
#
#  Note that:
#
#     Comment list 1 can exist on any subtree, but its association with
#        tree components can be upset by rerooting
#     Comment list 2 cannot exist without a descendant list
#     Comment list 3 cannot exist without a label
#     Comment lists 4 and 5 cannot exist without a branch length
#
#  Elements in perl representation are:
#
#     $tree = \@rootnode;
#
#     $node = [ \@desc,  #  reference to list of descendants
#                $label, #  node label
#                $x,     #  branch length
#               \@c1,    #  reference to comment list 1
#               \@c2,    #  reference to comment list 2
#               \@c3,    #  reference to comment list 3
#               \@c4,    #  reference to comment list 4
#               \@c5     #  reference to comment list 5
#             ]
#
#  At present, no routine tests or enforces the length of the list (a single
#  element list could be a valid internal node).
#
#  All empty lists can be [] or undef
#
#  Putting the comments at the end allows a shorter list nearly all the
#  time, but is different from the prolog representation.
#
#
#  Ross Overbeek has a different tree node structure:
#
#     $node = [ Label,
#               DistanceToParent,
#               [ ParentPointer, ChildPointer1, ... ],
#               [ Name1\tVal1, Name2\tVal2, ... ]
#             ]
#
#  So:
#
#===============================================================================
#  Tree format interconversion:
#===============================================================================
#
#  $bool      = is_overbeek_tree( $tree )
#  $bool      = is_gjonewick_tree( $tree )
#
#  $gjonewick = overbeek_to_gjonewick( $overbeek )
#  $overbeek  = gjonewick_to_overbeek( $gjonewick )
#
#===============================================================================
#  Tree data extraction:
#===============================================================================
#
#  $listref  = newick_desc_ref( $noderef )
#  $label    = newick_lbl( $noderef )
#  $x        = newick_x( $noderef )
#  $listref  = newick_c1( $noderef )
#  $listref  = newick_c2( $noderef )
#  $listref  = newick_c3( $noderef )
#  $listref  = newick_c4( $noderef )
#  $listref  = newick_c5( $noderef )
#
#  @desclist = newick_desc_list( $noderef )
#  $n        = newick_n_desc( $noderef )
#  $descref  = newick_desc_i( $noderef, $i )    # 1-based numbering
#
#  $bool     = node_is_tip( $noderef )
#  $bool     = node_is_valid( $noderef )
#  $bool     = node_has_lbl( $noderef )
#  $bool     = node_lbl_is( $noderef, $label )
#
#  set_newick_desc_ref( $noderef, $listref )
#  set_newick_lbl( $noderef, $label )
#  set_newick_x( $noderef, $x )
#  set_newick_c1( $noderef, $listref )
#  set_newick_c2( $noderef, $listref )
#  set_newick_c3( $noderef, $listref )
#  set_newick_c4( $noderef, $listref )
#  set_newick_c5( $noderef, $listref )
#  set_newick_desc_list( $noderef, @desclist )
#  set_newick_desc_i( $noderef1, $i, $noderef2 )  # 1-based numbering
#
#  $bool    = newick_is_valid( $noderef )       # verify that tree is valid
#
#  $bool    = newick_is_rooted( $noderef )      # 2 branches from root
#  $bool    = newick_is_unrooted( $noderef )    # 3 or more branches from root
#  $bool    = newick_is_tip_rooted( $noderef )  # 1 branch from root
#  $bool    = newick_is_bifurcating( $noderef )
#
#  $n       = newick_tip_count( $noderef )
#  @tiprefs = newick_tip_ref_list( $noderef )
# \@tiprefs = newick_tip_ref_list( $noderef )
#  @tips    = newick_tip_list( $noderef )
# \@tips    = newick_tip_list( $noderef )
#
#  $tipref  = newick_first_tip_ref( $noderef )
#  $tip     = newick_first_tip( $noderef )
#
#  @tips    = newick_duplicated_tips( $noderef )
# \@tips    = newick_duplicated_tips( $noderef )
#
#  $bool    = newick_tip_in_tree( $noderef, $tipname )
#
#  @tips    = newick_shared_tips( $tree1, $tree2 )
# \@tips    = newick_shared_tips( $tree1, $tree2 )
#
#  $length  = newick_tree_length( $noderef )
#
#  %tip_distances = newick_tip_distances( $noderef )
# \%tip_distances = newick_tip_distances( $noderef )
#
#  $xmax    = newick_max_X( $noderef )
#  ( $tipref,  $xmax ) = newick_most_distant_tip_ref( $noderef )
#  ( $tipname, $xmax ) = newick_most_distant_tip_name( $noderef )
#
#  Provide a standard name by which two trees can be compared for same topology
#
#  $stdname = std_tree_name( $tree )
#
#  Tree tip insertion point (tip is on branch of length x that
#  is inserted into branch connecting node1 and node2, a distance
#  x1 from node1 and x2 from node2):
#
#  [ $node1, $x1, $node2, $x2, $x ] = newick_tip_insertion_point( $tree, $tip )
#
#  Standardized label for a node in terms of intersection of 3 lowest sorting
#  tips (sort is lower case):
#
#  @TipOrTips = std_node_name( $tree, $node )
#
#-------------------------------------------------------------------------------
#  Paths from root of tree:
#-------------------------------------------------------------------------------
#
#  Path descriptions are of form:
#      ( $node0, $i0, $node1, $i1, $node2, $i2, ..., $nodeN )
#      () is returned upon failure
#
#  @path  = path_to_tip( $treenode, $tipname )
# \%paths = paths_to_tips( $treenode, \@%tips )
#  @path  = path_to_named_node( $treenode, $nodename )
# \%paths = paths_to_named_nodes( $treenode, \@names )
#  @path  = path_to_node_ref( $treenode, $noderef )
#
#  @path  = path_to_node( $node,   $name1, $name2, $name3   )  #  3 node names
#  @path  = path_to_node( $node, [ $name1, $name2, $name3 ] )  #  Array of names
#  @path  = path_to_node( $node,   $name1, $name2   )          #  2 node names
#  @path  = path_to_node( $node, [ $name1, $name2 ] )          #  Array of names
#  @path  = path_to_node( $node,   $name1   )                  #  1 node name
#  @path  = path_to_node( $node, [ $name1 ] )                  #  Array with name
#
#  $distance = newick_path_length( @path )
#  $distance = tip_to_tip_distance( $tree, $tip1, $tip2 )
#  $distance = node_to_node_distance( $tree, $node1, $node2 )
#
#
#===============================================================================
#  Tree manipulations:
#===============================================================================
#
#  $treecopy = copy_newick_tree( $tree )
#
#-------------------------------------------------------------------------------
#  The following modify the existing tree, and possibly any components of that
#  tree that are reached by reference.  If the old version is still needed, copy
#  before modifying.
#-------------------------------------------------------------------------------
#
#  Modify labels:
#
#  $newtree = newick_relabel_nodes( $node, \%new_name )
#  $newtree = newick_relabel_nodes_i( $node, \%new_name )
#  $newtree = newick_relabel_tips( $node, \%new_name )
#  $newtree = newick_relabel_tips_i( $node, \%new_name )
#
#  Modify branches:
#
#  $n_changed = newick_set_undefined_branches( $node, $x )
#  $n_changed = newick_set_all_branches( $node, $x )
#  $n_changed = newick_fix_negative_branches( $tree )
#  $node      = newick_rescale_branches( $node, $factor )
#  $node      = newick_random_branch_lengths( $node, $x1, $x2 )
#  $node      = newick_modify_branches( $node, \&function )
#  $node      = newick_modify_branches( $node, \&function, \@func_parms )
#
#  Modify comments:
#
#  $node = newick_strip_comments( $node )
#
#  Modify rooting and/or order:
#
#  $nrmtree = normalize_newick_tree( $tree )
#  $revtree = reverse_newick_tree( $tree )
#  $stdtree = std_unrooted_newick( $tree )
#  $newtree = aesthetic_newick_tree( $tree, $direction )
#  $rndtree = random_order_newick_tree( $tree )
#  $newtree - reroot_tree( $tree, \%options )
#  $newtree = reroot_newick_by_path( @path )
#  $newtree = reroot_newick_to_tip( $tree, $tip )
#  $newtree = reroot_newick_next_to_tip( $tree, $tip )
#  $newtree = reroot_newick_to_node( $tree, @node )
#  $newtree = reroot_newick_to_node_ref( $tree, $noderef )
#  $newtree = reroot_newick_between_nodes( $tree, $node1, $node2, $fraction )
#  $newtree = reroot_newick_at_dist_between_nodes( $tree, $node1, $node2, $distance )
#  $newtree = reroot_newick_to_midpoint( $tree )           # unweighted
#  $newtree = reroot_newick_to_midpoint_w( $tree )         # weight by tips
#  $newtree = reroot_newick_to_approx_midpoint( $tree )    # unweighted
#  $newtree = reroot_newick_to_approx_midpoint_w( $tree )  # weight by tips
#  $newtree = uproot_tip_rooted_newick( $tree )
#  $newtree = uproot_newick( $tree )
#
#  $newtree = prune_from_newick( $tree, $tip )
#  $newtree = rooted_newick_subtree( $tree,  @tips )
#  $newtree = rooted_newick_subtree( $tree, \@tips )
#  $newtree = newick_subtree( $tree,  @tips )
#  $newtree = newick_subtree( $tree, \@tips )
#  $newtree = newick_covering_subtree( $tree,  @tips )
#  $newtree = newick_covering_subtree( $tree, \@tips )
#
#  $newtree = collapse_zero_length_branches( $tree )
#
#  $node = newick_insert_at_node( $node, $subtree )
#  $tree = newick_insert_between_nodes( $tree, $subtree, $node1, $node2, $fraction )
#
#===============================================================================
#  Tree neighborhood: subtree of n tips to represent a larger tree.
#===============================================================================
#
#  Focus around root:
#
#  $subtree = root_neighborhood_representative_tree( $tree, $n, \%tip_priority )
#  $subtree = root_neighborhood_representative_tree( $tree, $n )
#  @tips    = root_neighborhood_representative_tips( $tree, $n, \%tip_priority )
#  @tips    = root_neighborhood_representative_tips( $tree, $n )
# \@tips    = root_neighborhood_representative_tips( $tree, $n, \%tip_priority )
# \@tips    = root_neighborhood_representative_tips( $tree, $n )
#
#  Focus around a tip insertion point (the tip is not in the subtree):
#
#  $subtree = tip_neighborhood_representative_tree( $tree, $tip, $n, \%tip_priority )
#  $subtree = tip_neighborhood_representative_tree( $tree, $tip, $n )
#  @tips    = tip_neighborhood_representative_tips( $tree, $tip, $n, \%tip_priority )
#  @tips    = tip_neighborhood_representative_tips( $tree, $tip, $n )
# \@tips    = tip_neighborhood_representative_tips( $tree, $tip, $n, \%tip_priority )
# \@tips    = tip_neighborhood_representative_tips( $tree, $tip, $n )
#
#===============================================================================
#  Random trees
#===============================================================================
#
#   $tree = random_equibranch_tree(  @tips, \%options )
#   $tree = random_equibranch_tree( \@tips, \%options )
#   $tree = random_equibranch_tree(  @tips )
#   $tree = random_equibranch_tree( \@tips )
#
#   $tree = random_ultrametric_tree(  @tips, \%options )
#   $tree = random_ultrametric_tree( \@tips, \%options )
#   $tree = random_ultrametric_tree(  @tips )
#   $tree = random_ultrametric_tree( \@tips )
#
#===============================================================================
#  Tree reading and writing:
#===============================================================================
#  Write machine-readable trees:
#
#   writeNewickTree( $tree )
#   writeNewickTree( $tree, $file )
#   writeNewickTree( $tree, \*FH )
#  fwriteNewickTree( $file, $tree )  # Matches the C arg list for f... I/O
#  $treestring = swriteNewickTree( $tree )
#  $treestring = formatNewickTree( $tree )
#
#  Write human-readable trees:
#
#  @textlines  = text_plot_newick( $node, $width, $min_dx, $dy )
#   printer_plot_newick( $node, $file, $width, $min_dx, $dy )
#
#  Read trees:
#
#  $tree  = read_newick_tree( $file )  # reads to a semicolon
#  @trees = read_newick_trees( $file ) # reads to end of file
#  $tree  = parse_newick_tree_str( $string )
#
#===============================================================================


use Carp;
use Data::Dumper;
use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
        is_overbeek_tree
        is_gjonewick_tree
        overbeek_to_gjonewick
        gjonewick_to_overbeek
        newick_is_valid
        newick_is_rooted
        newick_is_unrooted
        tree_rooted_on_tip
        newick_is_bifurcating
        newick_tip_count
        newick_tip_ref_list
        newick_tip_list

        newick_first_tip
        newick_duplicated_tips
        newick_tip_in_tree
        newick_shared_tips

        newick_tree_length
        newick_tip_distances
        newick_max_X
        newick_most_distant_tip_ref
        newick_most_distant_tip_name

        newick_tip_insertion_point

        std_tree_name

        path_to_tip
        path_to_named_node
        path_to_node_ref
        path_to_node

        newick_path_length
        tip_to_tip_distance
        node_to_node_distance

        copy_newick_tree

        newick_relabel_nodes
        newick_relabel_nodes_i
        newick_relabel_tips
        newick_relabel_tips_i

        newick_set_undefined_branches
        newick_set_all_branches
        newick_fix_negative_branches
        newick_rescale_branches
        newick_random_branch_lengths
        newick_modify_branches

        newick_strip_comments

        normalize_newick_tree
        reverse_newick_tree
        std_unrooted_newick
        aesthetic_newick_tree
        unaesthetic_newick_tree
        random_order_newick_tree

        reroot_tree
        reroot_newick_by_path
        reroot_newick_to_tip
        reroot_newick_next_to_tip
        reroot_newick_to_node
        reroot_newick_to_node_ref
        reroot_newick_between_nodes
        reroot_newick_at_dist_between_nodes
        reroot_newick_to_midpoint
        reroot_newick_to_midpoint_w
        reroot_newick_to_approx_midpoint
        reroot_newick_to_approx_midpoint_w
        uproot_tip_rooted_newick
        uproot_newick

        prune_from_newick
        rooted_newick_subtree
        newick_subtree
        newick_covering_subtree
        collapse_zero_length_branches

        newick_insert_at_node
        newick_insert_between_nodes

        root_neighborhood_representative_tree
        root_neighborhood_representative_tips
        tip_neighborhood_representative_tree
        tip_neighborhood_representative_tips

        random_equibranch_tree
        random_ultrametric_tree

        writeNewickTree
        fwriteNewickTree
        strNewickTree
        formatNewickTree

        read_newick_tree
        read_newick_trees
        parse_newick_tree_str

        printer_plot_newick
        text_plot_newick
        );

our @EXPORT_OK = qw(
        newick_desc_ref
        newick_lbl
        newick_x
        newick_c1
        newick_c2
        newick_c3
        newick_c4
        newick_c5
        newick_desc_list
        newick_n_desc
        newick_desc_i

        node_is_tip
        node_is_valid
        node_has_lbl
        node_lbl_is

        set_newick_desc_ref
        set_newick_lbl
        set_newick_x
        set_newick_c1
        set_newick_c2
        set_newick_c3
        set_newick_c4
        set_newick_c5

        set_newick_desc_list
        set_newick_desc_i

        add_to_newick_branch
        dump_tree
        );


#-------------------------------------------------------------------------------
#  Internally used definitions
#-------------------------------------------------------------------------------

sub array_ref { $_[0] && ref( $_[0] ) eq 'ARRAY' }
sub hash_ref  { $_[0] && ref( $_[0] ) eq 'HASH'  }

sub max       { $_[0] >= $_[1] ? $_[0] : $_[1] }
sub min       { $_[0] <= $_[1] ? $_[0] : $_[1] }


#===============================================================================
#  Interconvert overbeek and gjonewick trees:
#===============================================================================

sub is_overbeek_tree  { array_ref( $_[0] ) && array_ref( $_[0]->[2] ) }

sub is_gjonewick_tree { array_ref( $_[0] ) && array_ref( $_[0]->[0] ) }

sub overbeek_to_gjonewick
{
    return () unless ref( $_[0] ) eq 'ARRAY';
    my ( $lbl, $x, $desc ) = @{ $_[0] };
    my ( undef, @desc ) = ( $desc && ref( $desc ) eq 'ARRAY' ) ? @$desc : ();
    [ [ map { overbeek_to_gjonewick( $_ ) } @desc ], $lbl, $x ]
}

sub gjonewick_to_overbeek
{
    return () unless ref( $_[0] ) eq 'ARRAY';
    my ( $desc, $lbl, $x ) = @{ $_[0] };
    my @desc   = ( $desc && ref( $desc ) eq 'ARRAY' ) ? @$desc : ();
    my $parent = $_[1];
    my $node   = [ $lbl, $x, undef, [] ];
    $node->[2] = [ $parent, map { gjonewick_to_overbeek( $_, $node ) } @desc ];
    return $node;
}


#===============================================================================
#  Extract tree structure values:
#===============================================================================
#
#     $listref = newick_desc_ref( $noderef )
#     $string  = newick_lbl( $noderef )
#     $real    = newick_x( $noderef )
#     $listref = newick_c1( $noderef )
#     $listref = newick_c2( $noderef )
#     $listref = newick_c3( $noderef )
#     $listref = newick_c4( $noderef )
#     $listref = newick_c5( $noderef )
#     @list    = newick_desc_list( $noderef )
#     $int     = newick_n_desc( $noderef )
#     $listref = newick_desc_i( $noderef )
#
#     $bool    = node_is_tip( $noderef )
#     $bool    = node_is_valid( $noderef )
#     $bool    = node_has_lbl( $noderef )
#     $bool    = node_lbl_is( $noderef, $label )
#
#-------------------------------------------------------------------------------

sub newick_desc_ref { ref($_[0]) ? $_[0]->[0] : Carp::confess() }
sub newick_lbl      { ref($_[0]) ? $_[0]->[1] : Carp::confess() }
sub newick_x        { ref($_[0]) ? $_[0]->[2] : Carp::confess() }
sub newick_c1       { ref($_[0]) ? $_[0]->[3] : Carp::confess() }
sub newick_c2       { ref($_[0]) ? $_[0]->[4] : Carp::confess() }
sub newick_c3       { ref($_[0]) ? $_[0]->[5] : Carp::confess() }
sub newick_c4       { ref($_[0]) ? $_[0]->[6] : Carp::confess() }
sub newick_c5       { ref($_[0]) ? $_[0]->[7] : Carp::confess() }

sub newick_desc_list
{
    local $_ = $_[0];
    array_ref( $_ ) && array_ref( $_->[0] ) ? @{ $_->[0] } : ();
}

sub newick_n_desc
{
    local $_ = $_[0];
    array_ref( $_ ) && array_ref( $_->[0] ) ? scalar @{ $_->[0] } : 0;
}

sub newick_desc_i
{
    local $_ = $_[0];
    my    $i = $_[1];
    array_ref( $_ ) && $i && array_ref( $_->[0] ) ? $_->[0]->[$i-1] : undef;
}

sub node_is_tip
{
    local $_ = $_[0];
    ! array_ref( $_ )      ? undef             :  # Not a node ref
      array_ref( $_->[0] ) ? @{ $_->[0] } == 0 :  # Empty descend list?
                             1                 ;  # No descend list
}

sub node_is_valid      #  An array ref with nonempty descend list or a label
{
    local $_ = $_[0];
    array_ref( $_ ) && ( array_ref( $_->[0] ) && @{ $_->[0] } || defined( $_->[1] ) )
}

sub node_has_lbl { local $_ = $_[0]->[1]; defined( $_ ) && ( $_ ne '' ) }

sub node_lbl_is { local $_ = $_[0]->[1]; defined( $_ ) && ( $_ eq $_[1] ) }


#-------------------------------------------------------------------------------
#  Set tree structure values
#-------------------------------------------------------------------------------

sub set_newick_desc_ref { $_[0]->[0] = $_[1] }
sub set_newick_lbl      { $_[0]->[1] = $_[1] }
sub set_newick_x        { $_[0]->[2] = $_[1] }
sub set_newick_c1       { $_[0]->[3] = $_[1] }
sub set_newick_c2       { $_[0]->[4] = $_[1] }
sub set_newick_c3       { $_[0]->[5] = $_[1] }
sub set_newick_c4       { $_[0]->[6] = $_[1] }
sub set_newick_c5       { $_[0]->[7] = $_[1] }

sub set_newick_desc_list
{
    local $_ = shift;
    array_ref( $_ ) || return;
    if ( array_ref( $_->[0] ) ) { @{ $_->[0] } =   @_   }
    else                        {    $_->[0]   = [ @_ ] }
}

sub set_newick_desc_i
{
    my ( $node1, $i, $node2 ) = @_;
    array_ref( $node1 ) && array_ref( $node2 ) || return;
    if ( array_ref( $node1->[0] ) ) { $node1->[0]->[$i-1] =   $node2   }
    else                            { $node1->[0]         = [ $node2 ] }
}


#===============================================================================
#  Some tree property tests:
#===============================================================================
#  Tree is valid?
#
#  $bool = newick_is_valid( $node, $verbose )
#-------------------------------------------------------------------------------
sub newick_is_valid
{
    my $node = shift;

    if ( ! array_ref( $node ) )
    {
        print STDERR "Node is not array reference\n" if $_[0];
        return 0;
    }

    my @node = @$node;
    if ( ! @node )
    {
        print STDERR "Node is empty array reference\n" if $_[0];
        return 0;
    }

    # Must have descendant or label:

    if ( ! ( array_ref( $node[0] ) && @{ $node[0] } ) && ! $node[2] )
    {
        print STDERR "Node has neither descendant nor label\n" if $_[0];
        return 0;
    }

    #  If comments are present, they must be array references

    foreach ( ( @node > 3 ) ? @node[ 3 .. $#node ] : () )
    {
        if ( defined( $_ ) && ! array_ref( $_ ) )
        {
            print STDERR "Node has neither descendant or label\n" if $_[0];
            return 0;
        }
    }

    #  Inspect the descendants:

    foreach ( array_ref( $node[0] ) ? @{ $node[0] } : () )
    {
        newick_is_valid( $_, @_ ) || return 0
    }

    return 1;
}


#-------------------------------------------------------------------------------
#  Tree is rooted (2 branches at root node)?
#
#  $bool = newick_is_rooted( $node )
#-------------------------------------------------------------------------------
sub newick_is_rooted
{
    local $_ = $_[0];
    ! array_ref( $_      ) ? undef             :  # Not a node ref
      array_ref( $_->[0] ) ? @{ $_->[0] } == 2 :  # 2 branches
                             0                 ;  # No descend list
}


#-------------------------------------------------------------------------------
#  Tree is unrooted (> 2 branches at root node)?
#
#  $bool = newick_is_unrooted( $node )
#-------------------------------------------------------------------------------
sub newick_is_unrooted
{
    local $_ = $_[0];
    ! array_ref( $_      ) ? undef             :  # Not a node ref
      array_ref( $_->[0] ) ? @{ $_->[0] } >= 3 :  # Over 2 branches
                             0                 ;  # No descend list
}


#-------------------------------------------------------------------------------
#  Tree is rooted on a tip (1 branch at root node)?
#
#  $bool = newick_is_tip_rooted( $node )
#-------------------------------------------------------------------------------
sub newick_is_tip_rooted
{
    local $_ = $_[0];
    ! array_ref( $_      ) ? undef             :  # Not a node ref
      array_ref( $_->[0] ) ? @{ $_->[0] } == 1 :  # 1 branch
                             0                 ;  # No descend list
}

#===============================================================================
#  Everything below this point refers to parts of the tree structure using
#  only the routines above.
#===============================================================================
#  Tree is bifurcating?  If so, return number of descendents of root node.
#
#  $n_desc = newick_is_bifurcating( $node )
#-------------------------------------------------------------------------------
sub newick_is_bifurcating
{
    my ( $node, $not_root ) = @_;
    if ( ! array_ref( $node ) ) { return undef }    #  Bad arg

    my $n = newick_n_desc( $node );
    $n == 0 && ! $not_root                                             ? 0 :
    $n == 1 &&   $not_root                                             ? 0 :
    $n == 3 &&   $not_root                                             ? 0 :
    $n >  3                                                            ? 0 :
    $n >  2 && ! newick_is_bifurcating( newick_desc_i( $node, 3, 1 ) ) ? 0 :
    $n >  1 && ! newick_is_bifurcating( newick_desc_i( $node, 2, 1 ) ) ? 0 :
    $n >  0 && ! newick_is_bifurcating( newick_desc_i( $node, 1, 1 ) ) ? 0 :
                                                                         $n
}


#-------------------------------------------------------------------------------
#  Number of tips:
#
#  $n = newick_tip_count( $node )
#-------------------------------------------------------------------------------
sub newick_tip_count
{
    my ( $node, $not_root ) = @_;

    my $imax = newick_n_desc( $node );
    if ( $imax < 1 ) { return 1 }

    #  Special case for tree rooted on tip

    my $n = ( $imax == 1 && ( ! $not_root ) ) ? 1 : 0;

    foreach ( newick_desc_list( $node ) ) { $n += newick_tip_count( $_, 1 ) }

    $n;
}


#-------------------------------------------------------------------------------
#  List of tip nodes:
#
#  @tips = newick_tip_ref_list( $noderef )
# \@tips = newick_tip_ref_list( $noderef )
#-------------------------------------------------------------------------------
sub newick_tip_ref_list
{
    my ( $node, $not_root ) = @_;

    my $imax = newick_n_desc( $node );
    if ( $imax < 1 ) { return $node }

    my @list = ();

    #  Tree rooted on tip?
    if ( ! $not_root && ( $imax == 1 ) && node_has_lbl( $node ) ) { push @list, $node }

    foreach ( newick_desc_list( $node ) ) {
        push @list, newick_tip_ref_list( $_, 1 );
    }

    wantarray ? @list : \@list;
}


#-------------------------------------------------------------------------------
#  List of tips:
#
#  @tips = newick_tip_list( $node )
# \@tips = newick_tip_list( $node )
#-------------------------------------------------------------------------------
sub newick_tip_list
{
    my @tips = map { newick_lbl( $_ ) } newick_tip_ref_list( $_[0] );
    wantarray ? @tips : \@tips;
}


#-------------------------------------------------------------------------------
#  First tip node in tree:
#
#  $tipref = newick_first_tip_ref( $node )
#-------------------------------------------------------------------------------
sub newick_first_tip_ref
{
    my ( $node, $not_root ) = @_;
    valid_node( $node ) || return  undef;

    #  Arrived at tip, or start of a tip-rooted tree?
    my $n = newick_n_desc( $node );
    if ( ( $n < 1 ) || ( $n == 1 && ! $not_root ) ) { return $node }

    newick_first_tip_ref( newick_desc_i( $node, 1 ), 1 );
}


#-------------------------------------------------------------------------------
#  First tip name in tree:
#
#  $tip = newick_first_tip( $node )
#-------------------------------------------------------------------------------
sub newick_first_tip
{
    my ( $noderef ) = @_;

    my $tipref;
    array_ref( $tipref = newick_first_tip_ref( $noderef ) ) ? newick_lbl( $tipref )
                                                            : undef;
}


#-------------------------------------------------------------------------------
#  List of duplicated tip labels.
#
#  @tips = newick_duplicated_tips( $node )
# \@tips = newick_duplicated_tips( $node )
#-------------------------------------------------------------------------------
sub newick_duplicated_tips
{
    my @tips = &duplicates( newick_tip_list( $_[0] ) );
    wantarray ? @tips : \@tips;
}


#-------------------------------------------------------------------------------
#  Tip in tree?
#
#  $bool = newick_tip_in_tree( $node, $tipname )
#-------------------------------------------------------------------------------
sub newick_tip_in_tree
{
    my ( $node, $tip, $not_root ) = @_;

    my $n = newick_n_desc( $node );
    if ( $n < 1 ) { return node_lbl_is( $node, $tip ) ? 1 : 0 }

    #  Special case for tree rooted on tip

    if ( ( $n == 1 ) && ( ! $not_root ) && node_lbl_is( $node, $tip ) )
    {
        return 1
    }

    foreach ( newick_desc_list( $node ) ) {
        if ( newick_tip_in_tree( $_, $tip, 1 ) ) { return 1 }
    }

    0;    #  Fall through means not found
}


#-------------------------------------------------------------------------------
#  Tips shared between 2 trees.
#
#  @tips = newick_shared_tips( $tree1, $tree2 )
# \@tips = newick_shared_tips( $tree1, $tree2 )
#-------------------------------------------------------------------------------
sub newick_shared_tips
{
    my ( $tree1, $tree2 ) = @_;
    my $tips1 = newick_tip_list( $tree1 );
    my $tips2 = newick_tip_list( $tree2 );
    my @tips = &intersection( $tips1, $tips2 );
    wantarray ? @tips : \@tips;
}


#-------------------------------------------------------------------------------
#  Tree length.
#
#  $length = newick_tree_length( $node )
#-------------------------------------------------------------------------------
sub newick_tree_length
{
    my ( $node, $not_root ) = @_;

    my $x = $not_root ? newick_x( $node ) : 0;
    defined( $x ) || ( $x = 1 );                #  Convert undefined to 1

    foreach ( newick_desc_list( $node ) ) { $x += newick_tree_length( $_, 1 ) }

    $x;
}


#-------------------------------------------------------------------------------
#  Hash of tip nodes and corresponding distances from root:
#
#   %tip_distances = newick_tip_distances( $node )
#  \%tip_distances = newick_tip_distances( $node )
#-------------------------------------------------------------------------------
sub newick_tip_distances
{
    my ( $node, $x, $hash ) = @_;
    my $root = ! $hash;
    ref( $hash ) eq 'HASH' or $hash = {};

    $x ||= 0;
    $x  += newick_x( $node ) || 0;

    #  Is it a tip?

    my $n_desc = newick_n_desc( $node );
    if ( ! $n_desc )
    {
        $hash->{ newick_lbl( $node ) } = $x;
        return $hash;
    }

    #  Tree rooted on tip?

    if ( $root && ( $n_desc == 1 ) && node_has_lbl( $node ) )
    {
        $hash->{ newick_lbl( $node ) } = 0;  # Distance to root is zero
    }

    foreach ( newick_desc_list( $node ) ) { newick_tip_distances( $_, $x, $hash ) }

    wantarray ? %$hash : $hash;
}


#-------------------------------------------------------------------------------
#  Tree max X.
#
#  $xmax = newick_max_X( $node )
#-------------------------------------------------------------------------------
sub newick_max_X
{
    my ( $node, $not_root ) = @_;

    my $xmax = 0;
    foreach ( newick_desc_list( $node ) ) {
        my $x = newick_max_X( $_, 1 );
        if ( $x > $xmax ) { $xmax = $x }
    }

    my $x = $not_root ? newick_x( $node ) : 0;
    $xmax + ( defined( $x ) ? $x : 1 );           #  Convert undefined to 1
}


#-------------------------------------------------------------------------------
#  Most distant tip from root: distance and path.
#
#  ( $xmax, @path ) = newick_most_distant_tip_path( $tree )
#-------------------------------------------------------------------------------
sub newick_most_distant_tip_path
{
    my ( $node, $not_root ) = @_;

    my $imax = newick_n_desc( $node );
    my $xmax = ( $imax > 0 ) ? -1 : 0;
    my @pmax = ();
    for ( my $i = 1; $i <= $imax; $i++ ) {
        my ( $x, @path ) = newick_most_distant_tip_path( newick_desc_i( $node, $i ), 1 );
        if ( $x > $xmax ) { $xmax = $x; @pmax = ( $i, @path ) }
    }

    my $x = $not_root ? newick_x( $node ) : 0;
    $xmax += defined( $x ) ? $x : 0;            #  Convert undefined to 1
    ( $xmax, $node, @pmax );
}


#-------------------------------------------------------------------------------
#  Most distant tip from root, and its distance.
#
#  ( $tipref, $xmax ) = newick_most_distant_tip_ref( $tree )
#-------------------------------------------------------------------------------
sub newick_most_distant_tip_ref
{
    my ( $node, $not_root ) = @_;

    my $imax = newick_n_desc( $node );
    my $xmax = ( $imax > 0 ) ? -1 : 0;
    my $tmax = $node;
    foreach ( newick_desc_list( $node ) ) {
        my ( $t, $x ) = newick_most_distant_tip_ref( $_, 1 );
        if ( $x > $xmax ) { $xmax = $x; $tmax = $t }
    }

    my $x = $not_root ? newick_x( $node ) : 0;
    $xmax += defined( $x ) ? $x : 1;            #  Convert undefined to 1
    ( $tmax, $xmax );
}


#-------------------------------------------------------------------------------
#  Name of most distant tip from root, and its distance.
#
#  ( $tipname, $xmax ) = newick_most_distant_tip_name( $tree )
#-------------------------------------------------------------------------------
sub newick_most_distant_tip_name
{
    my ( $tipref, $xmax ) = newick_most_distant_tip_ref( $_[0] );
    ( newick_lbl( $tipref ), $xmax )
}


#-------------------------------------------------------------------------------
#  Tree tip insertion point (with standard node labels):
#
#  [ $node1, $x1, $node2, $x2, $x ]
#           = newick_tip_insertion_point( $tree, $tip )
#
#  Which means: tip is on a branch of length x that is inserted into the branch
#  connecting node1 and node2, at distance x1 from node1 and x2 from node2.
#
#                x1    +------ n1a (lowest sorting tip of this subtree)
#            +--------n1
#            |         +------n1b (lowest sorting tip of this subtree)
#  tip-------n
#        x   |       +------------- n2a (lowest sorting tip of this subtree)
#            +------n2
#               x2   +-------- n2b (lowest sorting tip of this subtree)
#
#  The designations of 1 vs 2, and a vs b are chosen such that:
#     n1a < n1b, and n2a < n2b, and n1a < n2a
#
#  Then the statandard description becomes:
#
#  [ [ $n1a, min(n1b,n2a), max(n1b,n2a) ], x1,
#    [ $n2a, min(n2b,n1a), max(n2b,n1a) ], x2,
#    x
#  ]
#
#-------------------------------------------------------------------------------
sub newick_tip_insertion_point
{
    my ( $tree, $tip ) = @_;
    $tree && $tip && ref( $tree ) eq 'ARRAY'    or return undef;
    $tree = copy_newick_tree( $tree )           or return undef;
    $tree = reroot_newick_to_tip( $tree, $tip ) or return undef;
    my $node = $tree;

    my $x  = 0;                        # Distance to node
    my $dl = newick_desc_ref( $node ); # Descendent list of tip node;
    $node  = $dl->[0];                 # Node adjacent to tip
    $dl    = newick_desc_ref( $node );
    while ( $dl && ( @$dl == 1 ) )     # Traverse unbranched nodes
    {
        $node = $dl->[0];
        $x   += newick_x( $node );
        $dl   = newick_desc_ref( $node );
    }
    $x += newick_x( $node );

    #  We are now at the node that is the insertion point.
    #  Is it a tip?

    my @description;

    if ( ( ! $dl ) || @$dl == 0 )
    {
        @description = ( [ newick_lbl( $node ) ], 0, undef, 0, $x );
    }

    #  Is it a trifurcation or greater, in which case it does not go
    #  away with tip deletion?

    elsif ( @$dl > 2 )
    {
        @description = ( [ std_node_name( $node, $node ) ], 0, undef, 0, $x );
    }

    #  The node is bifurcating.  We need to describe it.

    else
    {
        my ( $n1, $x1 ) = describe_descendant( $dl->[0] );
        my ( $n2, $x2 ) = describe_descendant( $dl->[1] );

        if ( @$n1 == 2 ) { push @$n1, $n2->[0] }
        if ( @$n2 == 2 )
        {
            @$n2 = sort { lc $a cmp lc $b } ( @$n2, $n1->[0] );
        }
        if ( @$n1 == 3 ) { @$n2 = sort { lc $a cmp lc $b } @$n2 }
        @description = ( $n1, $x1, $n2, $x2, $x );
    }

    return wantarray ? @description : \@description;
}


sub describe_descendant
{
    my $node = shift;

    my $x  = 0;                        # Distance to node
    my $dl = newick_desc_ref( $node ); # Descendent list of tip node;
    while ( $dl && ( @$dl == 1 ) )     # Traverse unbranched nodes
    {
        $node = $dl->[0];
        $x   += newick_x( $node );
        $dl   = newick_desc_ref( $node );
    }
    $x += newick_x( $node );

    #  Is it a tip?  Return list of one tip;

    if ( ( ! $dl ) || ! @$dl ) { return ( [ newick_lbl( $node ) ], $x ) }

    #  Get tips of each descendent, keeping lowest sorting from each.
    #  Return the two lowest of those (the third will come from the
    #  other side of the original node).

    my @rep_tips = sort { lc $a cmp lc $b }
                   map  { ( sort { lc $a cmp lc $b } newick_tip_list( $_ ) )[0] }
                   @$dl;
    return ( [ @rep_tips[0,1] ], $x );
}


#-------------------------------------------------------------------------------
#  Standard node name:
#     Tip label if at a tip
#     Three sorted tip labels intersecting at node, each being smallest
#           of all the tips of their subtrees
#
#  @TipOrTips = std_node_name( $tree, $node )
#-------------------------------------------------------------------------------
sub std_node_name
{
    my $tree = $_[0];

    #  Node reference is last element of path to node

    my $noderef = ( path_to_node( @_ ) )[-1];
    defined( $noderef ) || return ();

    if ( node_is_tip( $noderef ) || ( $noderef eq $tree ) ) {  # Is it a tip?
        return newick_lbl( $noderef );
    }

    #  Work through lists of tips in descendant subtrees, removing them from
    #  @rest, and keeping the best tip for each subtree.

    my @rest = newick_tip_list( $tree );
    my @best = map
          {
            my @tips = sort { lc $a cmp lc $b } newick_tip_list( $_ );
            @rest = &set_difference( \@rest, \@tips );
            $tips[0];
          } newick_desc_list( $noderef );

    # Best of the rest of the tree
    push @best, ( sort { lc $a cmp lc $b } @rest )[0];

    # Take the top 3, in order:

    ( @best >= 3 ) ? ( sort { lc $a cmp lc $b } @best )[0 .. 2] : ();
}


#===============================================================================
#  Functions to find paths in trees.
#
#  Path descriptions are of form:
#      ( $node0, $i0, $node1, $i1, $node2, $i2, ..., $nodeN )   # Always odd
#      () is returned upon failure
#
#  Numbering of descendants is 1-based.
#===============================================================================
#  Path to tip:
#
#  @path = path_to_tip( $treenode, $tipname )
#-------------------------------------------------------------------------------
sub path_to_tip
{
    my ( $node, $tip ) = @_;

    my $imax = newick_n_desc( $node );

    #  Tip (including root tip):

    return ( $node ) if ( $imax < 2 ) && node_lbl_is( $node, $tip );

    for ( my $i = 1; $i <= $imax; $i++ ) {
       my @suf = path_to_tip( newick_desc_i( $node, $i ), $tip );
       return ( $node, $i, @suf ) if @suf;
    }

    ();  #  Not found
}


#-------------------------------------------------------------------------------
#  Paths to tips:
#
#  \%paths = paths_to_tips( $treenode, \@tips )
#  \%paths = paths_to_tips( $treenode, \%tips )
#
#-------------------------------------------------------------------------------
sub paths_to_tips
{
    my ( $node, $tips ) = @_;
    return {} if ! ( $tips && ref( $tips ) );

    #  Replace request for list with request by hash

    if ( ref( $tips ) eq 'ARRAY' ) { $tips = { map { $_ => 1 } @$tips } }

    my $paths = {};
    my $imax = newick_n_desc( $node );
    if ( $imax < 2 )
    {
        my $lbl;
        if ( node_has_lbl( $node ) && defined( $lbl = newick_lbl( $node ) ) && $tips->{ $lbl } )
        {
            delete $tips->{ $lbl };
            $paths->{ $lbl } = [ $node ];
        }
        return $paths if ! $imax;  # tip (no more to do it tested below)
    }

    for ( my $i = 1; $i <= $imax && keys %$tips; $i++ )
    {
       my $new = paths_to_tips( newick_desc_i( $node, $i ), $tips );
       foreach ( keys %$new )
       {
           splice @{ $new->{ $_ } }, 0, 0, ( $node, $i );
           $paths->{ $_ } = $new->{ $_ };
       }
    }

    return $paths;
}


#-------------------------------------------------------------------------------
#  Path to named node.  Like path to tip, but also finds named internal nodes.
#
#  @path = path_to_named_node( $treenode, $name )
#
#-------------------------------------------------------------------------------
sub path_to_named_node
{
    my ( $node, $name ) = @_;

    return ( $node ) if node_lbl_is( $node, $name );

    my $imax = newick_n_desc( $node );
    for ( my $i = 1; $i <= $imax; $i++ ) {
       my @suf = path_to_named_node( newick_desc_i( $node, $i ), $name );
       return ( $node, $i, @suf ) if @suf;
    }

    ();  #  Not found
}


#-------------------------------------------------------------------------------
#  Paths to named nodes in tree (need not be tips):
#
#  \%paths = paths_to_named_nodes( $treenode, \@names )
#  \%paths = paths_to_named_nodes( $treenode, \%names )
#
#-------------------------------------------------------------------------------
sub paths_to_named_nodes
{
    my ( $node, $names ) = @_;
    return {} if ! ( $names && ref( $names ) );

    #  Replace request for list with request by hash

    if ( ref( $names ) eq 'ARRAY' ) { $names = { map { $_ => 1 } @$names } }

    my $paths = {};
    my $imax = newick_n_desc( $node );

    my $lbl;
    if ( node_has_lbl( $node ) && defined( $lbl = newick_lbl( $node ) ) && $names->{ $lbl } )
    {
        delete $names->{ $lbl };
        $paths->{ $lbl } = [ $node ];
    }
    return $paths if ! $imax;  # tip (no more to do it tested below)

    for ( my $i = 1; $i <= $imax && keys %$names; $i++ )
    {
       my $new = paths_to_named_nodes( newick_desc_i( $node, $i ), $names );
       foreach ( keys %$new )
       {
           splice @{ $new->{ $_ } }, 0, 0, ( $node, $i );
           $paths->{ $_ } = $new->{ $_ };
       }
    }

    return $paths;
}


#-------------------------------------------------------------------------------
#  Path to node reference.
#
#  @path = path_to_node_ref( $treenode, $noderef )
#
#-------------------------------------------------------------------------------
sub path_to_node_ref
{
    my ( $node, $noderef ) = @_;

    return ( $node ) if ( $node eq $noderef );

    my $imax = newick_n_desc( $node );
    for ( my $i = 1; $i <= $imax; $i++ ) {
        my @suf = path_to_node_ref( newick_desc_i( $node, $i ), $noderef );
        return ( $node, $i, @suf ) if @suf;
    }

    ();  #  Not found
}


#-------------------------------------------------------------------------------
#  Path to node, as defined by 1, 2 or 3 node names (usually tips).
#
#  @path = path_to_node( $tree,   $name1, $name2, $name3   )  #  3 tip names
#  @path = path_to_node( $tree, [ $name1, $name2, $name3 ] )  #  Allow array ref
#  @path = path_to_node( $tree,   $name1, $name2   )          #  2 tip names
#  @path = path_to_node( $tree, [ $name1, $name2 ] )          #  Allow array ref
#  @path = path_to_node( $tree,   $name1   )                  #  Path to tip or named node
#  @path = path_to_node( $tree, [ $name1 ] )                  #  Allow array ref
#
#-------------------------------------------------------------------------------
sub path_to_node
{
    my ( $tree, @names ) = @_;
    array_ref( $tree ) && defined( $names[0] ) || return ();

    # Allow arg 2 to be an array reference

    @names = @{ $names[0] }  if array_ref( $names[0] );

    return () if @names < 1 || @names > 3;

    #  Just one name:

    return path_to_named_node( $tree, $names[0] ) if ( @names == 1 );

    my @paths = values %{ paths_to_named_nodes( $tree, \@names ) };

    #  Were all node names found?

    return () if @paths != @names;

    my @path12 = &common_prefix( @paths[0,1] );
    return () if ! @path12;
    return @path12 if @paths == 2;

    my @path13 = &common_prefix( @paths[0,2] );
    my @path23 = &common_prefix( @paths[1,2] );

    # Return the longest common prefix of any two paths

    ( @path12 >= @path13 && @path12 >= @path23 ) ? @path12 :
    ( @path13 >= @path23 )                       ? @path13 :
                                                   @path23 ;
}


#-------------------------------------------------------------------------------
#  Distance along path.
#
#  $distance = newick_path_length( @path )
#
#-------------------------------------------------------------------------------
sub newick_path_length
{
    my $node = shift;      #  Discard the first node
    array_ref( $node ) || return undef;
    @_ ? distance_along_path_2( @_ ) : 0;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  This expects to get path minus root node:
#
#  $distance = distance_along_path_2( @path )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub distance_along_path_2
{
    shift;                 #  Discard descendant number
    my $node = shift;
    array_ref( $node ) || return undef;
    my $d1 = newick_x( $node );
    my $d2 = @_ ? distance_along_path_2( @_ ) : 0;
    defined( $d1 ) && defined( $d2 ) ? $d1 + $d2 : undef;
}


#-------------------------------------------------------------------------------
#  Tip-to-tip distance.
#
#  $distance = tip_to_tip_distance( $tree, $tip1, $tip2 )
#
#-------------------------------------------------------------------------------
sub tip_to_tip_distance
{
    my ( $node, $tip1, $tip2 ) = @_;

    array_ref( $node ) && defined( $tip1 )
                       && defined( $tip2 ) || return undef;
    my @p1 = path_to_tip( $node, $tip1 );
    my @p2 = path_to_tip( $node, $tip2 );
    @p1 && @p2 || return undef;                          # Were they found?

    # Find the unique suffixes of the two paths
    my ( $suf1, $suf2 ) = &unique_suffixes( \@p1, \@p2 ); # Common node is lost
    my $d1 = @$suf1 ? distance_along_path_2( @$suf1 ) : 0;
    my $d2 = @$suf2 ? distance_along_path_2( @$suf2 ) : 0;

    defined( $d1 ) && defined( $d2 ) ? $d1 + $d2 : undef;
}


#-------------------------------------------------------------------------------
#  Node-to-node distance.
#  Nodes can be:   $tipname
#                [ $tipname ]
#                [ $tipname1, $tipname2, $tipname3 ]
#
#  $distance = node_to_node_distance( $tree, $node1, $node2 )
#
#-------------------------------------------------------------------------------
sub node_to_node_distance
{
    my ( $node, $node1, $node2 ) = @_;

    array_ref( $node ) && defined( $node1 )
                       && defined( $node2 ) || return undef;
    my @p1 = path_to_node( $node, $node1 ) or return undef;
    my @p2 = path_to_node( $node, $node2 ) or return undef;

    # Find the unique suffixes of the two paths
    my ( $suf1, $suf2 ) = &unique_suffixes( \@p1, \@p2 ); # Common node is lost
    my $d1 = @$suf1 ? distance_along_path_2( @$suf1 ) : 0;
    my $d2 = @$suf2 ? distance_along_path_2( @$suf2 ) : 0;

    defined( $d1 ) && defined( $d2 ) ? $d1 + $d2 : undef;
}


#===============================================================================
#  Tree manipulations:
#===============================================================================
#  Copy tree.
#  Lists are copied, except that references to empty lists go to undef.
#  Only defined fields are added, so tree list may be shorter than 8 fields.
#
#  $treecopy = copy_newick_tree( $tree )
#
#-------------------------------------------------------------------------------
sub copy_newick_tree
{
    my ( $node ) = @_;
    array_ref( $node ) || return undef;

    my $nn = [];  #  Reference to a new node structure
    #  Build a new descendant list, if not empty
    my @dl = newick_desc_list( $node );
    set_newick_desc_ref( $nn, @dl ? [ map { copy_newick_tree( $_ ) } @dl ]
                                  : undef
                       );

    #  Copy label and x, if defined
    my ( $l, $x );
    if ( defined( $l = newick_lbl( $node ) ) ) { set_newick_lbl( $nn, $l ) }
    if ( defined( $x = newick_x(   $node ) ) ) { set_newick_x(   $nn, $x ) }

    #  Build new comment lists, when not empty ( does not extend array unless
    #  necessary)
    my $c;
    if ( $c = newick_c1( $node ) and @$c ) { set_newick_c1( $nn, [ @$c ] ) }
    if ( $c = newick_c2( $node ) and @$c ) { set_newick_c2( $nn, [ @$c ] ) }
    if ( $c = newick_c3( $node ) and @$c ) { set_newick_c3( $nn, [ @$c ] ) }
    if ( $c = newick_c4( $node ) and @$c ) { set_newick_c4( $nn, [ @$c ] ) }
    if ( $c = newick_c5( $node ) and @$c ) { set_newick_c5( $nn, [ @$c ] ) }

    $nn;
}


#-------------------------------------------------------------------------------
#  Use a hash to relabel the nodes in a newick tree.
#
#  $newtree = newick_relabel_nodes( $node, \%new_name )
#
#-------------------------------------------------------------------------------
sub newick_relabel_nodes
{
    my ( $node, $new_name ) = @_;

    my ( $new );
    if ( node_has_lbl( $node ) && defined( $new = $new_name->{ newick_lbl( $node ) } ) ) {
        set_newick_lbl( $node, $new );
    }

    foreach ( newick_desc_list( $node ) ) {
        newick_relabel_nodes( $_, $new_name );
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Use a hash to relabel the nodes in a newick tree (case insensitive).
#
#  $newtree = newick_relabel_nodes_i( $node, \%new_name )
#
#-------------------------------------------------------------------------------
sub newick_relabel_nodes_i
{
    my ( $node, $new_name ) = @_;

    #  Add any necessary lowercase keys to the hash:

    my $lc_lbl;
    foreach ( keys %$new_name ) {
        $lc_lbl = lc $_;
        ( $lc_lbl eq $_ ) or ( $new_name->{ $lc_lbl } = $new_name->{ $_ } );
    }

    newick_relabel_nodes_i2( $node, $new_name );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Do the actual relabeling
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub newick_relabel_nodes_i2
{
    my ( $node, $new_name ) = @_;

    my ( $new );
    if ( node_has_lbl( $node ) && defined( $new = $new_name->{ lc newick_lbl( $node ) } ) ) {
        set_newick_lbl( $node, $new );
    }

    foreach ( newick_desc_list( $node ) ) {
        newick_relabel_nodes_i2( $_, $new_name );
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Use a hash to relabel the tips in a newick tree.
#
#  $newtree = newick_relabel_tips( $node, \%new_name )
#
#-------------------------------------------------------------------------------
sub newick_relabel_tips
{
    my ( $node, $new_name ) = @_;

    my @desc = newick_desc_list( $node );

    if ( @desc ) {
        foreach ( @desc ) { newick_relabel_tips( $_, $new_name ) }
    }
    else {
        my ( $new );
        if ( node_has_lbl( $node ) && defined( $new = $new_name->{ newick_lbl( $node ) } ) ) {
            set_newick_lbl( $node, $new );
        }
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Use a hash to relabel the tips in a newick tree (case insensitive).
#
#  $newtree = newick_relabel_tips_i( $node, \%new_name )
#
#-------------------------------------------------------------------------------
sub newick_relabel_tips_i
{
    my ( $node, $new_name ) = @_;

    #  Add any necessary lowercase keys to the hash:

    my $lc_lbl;
    foreach ( keys %$new_name ) {
        $lc_lbl = lc $_;
        ( $lc_lbl eq $_ ) or ( $new_name->{ $lc_lbl } = $new_name->{ $_ } );
    }

    newick_relabel_tips_i2( $node, $new_name );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Do the actual relabeling
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub newick_relabel_tips_i2
{
    my ( $node, $new_name ) = @_;

    my @desc = newick_desc_list( $node );

    if ( @desc ) {
        foreach ( @desc ) { newick_relabel_tips_i2( $_, $new_name ) }
    }
    else {
        my ( $new );
        if ( node_has_lbl( $node ) && defined( $new = $new_name->{ lc newick_lbl( $node ) } ) ) {
            set_newick_lbl( $node, $new );
        }
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Set undefined branch lenghts (except root) to length x.
#
#  $n_changed = newick_set_undefined_branches( $node, $x )
#
#-------------------------------------------------------------------------------
sub newick_set_undefined_branches
{
    my ( $node, $x, $not_root ) = @_;

    my $n = 0;
    if ( $not_root && ! defined( newick_x( $node ) ) ) {
        set_newick_x( $node, $x );
        $n++;
    }

    foreach ( newick_desc_list( $node ) ) {
        $n += newick_set_undefined_branches( $_, $x, 1 );
    }

    $n;
}


#-------------------------------------------------------------------------------
#  Set all branch lenghts (except root) to length x.
#
#  $n_changed = newick_set_all_branches( $node, $x )
#
#-------------------------------------------------------------------------------
sub newick_set_all_branches
{
    my ( $node, $x, $not_root ) = @_;

    my $n = 0;
    if ( $not_root )
    {
        set_newick_x( $node, $x );
        $n++;
    }

    foreach ( newick_desc_list( $node ) )
    {
        $n += newick_set_all_branches( $_, $x, 1 );
    }

    $n;
}


#-------------------------------------------------------------------------------
#  Rescale all branch lenghts by factor.
#
#  $node = newick_rescale_branches( $node, $factor )
#
#-------------------------------------------------------------------------------
sub newick_rescale_branches
{
    my ( $node, $factor ) = @_;

    my $x = newick_x( $node );
    set_newick_x( $node, $factor * $x ) if $x;

    foreach ( newick_desc_list( $node ) )
    {
        newick_rescale_branches( $_, $factor );
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Set all branch lenghts (except root) to random number between x1 and x2.
#
#  $node = newick_random_branch_lengths( $node, $x1, $x2 )
#
#-------------------------------------------------------------------------------
sub newick_random_branch_lengths
{
    my ( $node, $x1, $x2 ) = @_;
    return undef if ! array_ref( $node );
    $x1 = 0        if ! defined( $x1 ) || $x1 < 0;
    $x2 = $x1 + 1  if ! defined( $x2 ) || $x2 < $x1;
    newick_random_branch_lengths_0( $node, $x1, $x2, 0 );
}


sub newick_random_branch_lengths_0
{
    my ( $node, $x1, $x2, $not_root ) = @_;

    set_newick_x( $node, rand($x2-$x1) + $x1 ) if ( $not_root );
    foreach ( newick_desc_list( $node ) ) { newick_random_branch_lengths_0( $_, $x1, $x2, 1 ) }

    $node;
}


#-------------------------------------------------------------------------------
#  Modify all branch lengths by a function.
#
#     $node = newick_modify_branches( $node, \&function )
#     $node = newick_modify_branches( $node, \&function, \@func_parms )
#
#  Function must have form
#
#     $x2 = &$function( $x1 )
#     $x2 = &$function( $x1, @$func_parms )
#
#-------------------------------------------------------------------------------
sub newick_modify_branches
{
    my ( $node, $func, $parm ) = @_;

    set_newick_x( $node, &$func( newick_x( $node ), ( $parm ? @$parm : () ) ) );
    foreach ( newick_desc_list( $node ) )
    {
        newick_modify_branches( $_, $func, $parm )
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Set negative branches to zero.  The original tree is modfied.
#
#  $n_changed = newick_fix_negative_branches( $tree )
#
#-------------------------------------------------------------------------------
sub newick_fix_negative_branches
{
    my ( $tree ) = @_;
    array_ref( $tree ) or return undef;
    my $n_changed = 0;
    my $x = newick_x( $tree );
    if ( defined( $x ) and $x < 0 )
    {
        set_newick_x( $tree, 0 );
        $n_changed++;
    }

    foreach ( newick_desc_list( $tree ) )
    {
        $n_changed += newick_fix_negative_branches( $_ );
    }

    $n_changed;
}


#-------------------------------------------------------------------------------
#  Remove comments from a newick tree (e.g., before writing for phylip).
#
#  $node = newick_strip_comments( $node )
#
#-------------------------------------------------------------------------------
sub newick_strip_comments
{
    my ( $node ) = @_;

    @$node = @$node[ 0 .. 2 ];
    foreach ( newick_desc_list( $node ) ) { newick_strip_comments( $_ ) }
    $node;
}


#-------------------------------------------------------------------------------
#  Normalize tree order (in place).
#
#  ( $tree, $label1 ) = normalize_newick_tree( $tree )
#
#-------------------------------------------------------------------------------
sub normalize_newick_tree
{
    my ( $node ) = @_;

    my @descends = newick_desc_list( $node );
    if ( @descends == 0 ) { return ( $node, lc newick_lbl( $node ) ) }

    my %hash = map { ( normalize_newick_tree($_) )[1] => $_ } @descends;
    my @keylist = sort { $a cmp $b } keys %hash;
    set_newick_desc_list( $node, map { $hash{$_} } @keylist );

    ( $node, $keylist[0] );
}


#-------------------------------------------------------------------------------
#  Reverse tree order (in place).
#
#  $tree = reverse_newick_tree( $tree )
#
#-------------------------------------------------------------------------------
sub reverse_newick_tree
{
    my ( $node ) = @_;

    my @descends = newick_desc_list( $node );
    if ( @descends ) {
        set_newick_desc_list( $node, reverse @descends );
        foreach ( @descends ) { reverse_newick_tree( $_ ) }
    }
    $node;
}


#-------------------------------------------------------------------------------
#  Standard unrooted tree (in place).
#
#  $stdtree = std_unrooted_newick( $tree )
#
#-------------------------------------------------------------------------------
sub std_unrooted_newick
{
    my ( $tree ) = @_;

    my ( $mintip ) = sort { lc $a cmp lc $b } newick_tip_list( $tree );
    ( normalize_newick_tree( reroot_newick_next_to_tip( $tree, $mintip ) ) )[0];
}


#-------------------------------------------------------------------------------
#  Standard name for a Newick tree topology
#
#    $stdname = std_tree_name( $tree )
#
#-------------------------------------------------------------------------------
sub std_tree_name
{
    my ( $tree ) = @_;
    my ( $mintip ) = sort { lc $a cmp lc $b } newick_tip_list( $tree );
    ( std_tree_name_2( reroot_newick_next_to_tip( copy_newick_tree( $tree ), $mintip ) ) )[0];
}


#
#  ( $name, $mintip ) = std_tree_name_2( $node )
#
sub std_tree_name_2
{
    my ( $node ) = @_;
    
    my @descends = newick_desc_list( $node );
    if ( @descends == 0 )
    {
        my $lbl = newick_lbl( $node );
        return ( $lbl, $lbl );
    }

    my @list = sort { lc $a->[1] cmp lc $b->[1] || $a->[1] cmp $b->[1] }
               map  { [ std_tree_name_2( $_ ) ] }
               @descends;
    my $mintip = $list[0]->[1];
    my $name   = '(' . join( "\t", map { $_->[0] } @list ) . ')';

    return ( $name, $mintip );
}


#-------------------------------------------------------------------------------
#  Move largest groups to periphery of tree (in place).
#
#  $tree = aesthetic_newick_tree( $treeref, $dir )
#
#      dir  <= -2 for up-sweeping tree (big groups always first),
#            = -1 for big group first, balanced tree,
#            =  0 for balanced tree,
#            =  1 for small group first, balanced tree, and
#           >=  2 for down-sweeping tree (small groups always top)
#
#-------------------------------------------------------------------------------
sub aesthetic_newick_tree
{
    my ( $tree, $dir ) = @_;
    my %cnt;

    $dir = ! $dir       ?        0 :  #  Undefined or zero
             $dir <= -2 ? -1000000 :
             $dir <   0 ?       -1 :
             $dir >=  2 ?  1000000 :
                                 1 ;
    build_tip_count_hash( $tree, \%cnt );
    reorder_by_tip_count( $tree, \%cnt, $dir );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Build a hash to look up the number of descendants of each node.
#  Access count with $cntref->{$noderef}
#
#  $count = build_tip_count_hash( $node, $cnt_hash_ref )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub build_tip_count_hash
{
    my ( $node, $cntref ) = @_;
    my ( $i, $cnt );

    if ( newick_n_desc( $node ) < 1 ) { $cnt = 1 }
    else {
        $cnt = 0;
        foreach ( newick_desc_list( $node ) ) {
            $cnt += build_tip_count_hash( $_, $cntref );
        }
    }

    $cntref->{$node} = $cnt;
    $cnt;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $node = reorder_by_tip_count( $node, $cntref, $dir )
#      dir  < 0 for upward branch (big group first),
#           = 0 for no change, and
#           > 0 for downward branch (small group first).
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub reorder_by_tip_count
{
    my ( $node, $cntref, $dir ) = @_;

    my $nd = newick_n_desc( $node );
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip

    my $dl_ref = newick_desc_ref( $node );

    #  Reorder this subtree (biggest subtrees to outside)

    if ( $dir )
    {
        #  Big group first
        my @dl = sort { $cntref->{$b} <=> $cntref->{$a} } @$dl_ref;

        my ( @dl1, @dl2 );
        for ( my $i = 0; $i < $nd; $i++ ) {
            if ( $i & 1 ) { push @dl2, $dl[$i] } else { push @dl1, $dl[$i] }
        }

        @$dl_ref = ( $dir < 0 ) ? ( @dl1, reverse @dl2 )
                                : ( @dl2, reverse @dl1 );
    }

    #  Reorder within descendant subtrees:

    my $step = 0;
    if ( abs( $dir ) < 1e5 ) {
        $dir = 1 - $nd;                              #  Midgroup => as is
    #   $dir = 1 - $nd + ( $dir < 0 ? -0.5 : 0.5 );  #  Midgroup => outward
        $step = 2;
    }

    for ( my $i = 0; $i < $nd; $i++ ) {
        reorder_by_tip_count( $dl_ref->[$i], $cntref, $dir );
        $dir += $step;
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Move smallest groups to periphery of tree (in place).
#
#  $tree = unaesthetic_newick_tree( $treeref, $dir )
#
#      dir  <= -2 for up-sweeping tree (big groups always first),
#            = -1 for big group first, balanced tree,
#            =  0 for balanced tree,
#            =  1 for small group first, balanced tree, and
#           >=  2 for down-sweeping tree (small groups always top)
#
#-------------------------------------------------------------------------------
sub unaesthetic_newick_tree
{
    my ( $tree, $dir ) = @_;
    my %cnt;

    $dir = ! $dir       ?        0 :  #  Undefined or zero
             $dir <= -2 ? -1000000 :
             $dir <   0 ?       -1 :
             $dir >=  2 ?  1000000 :
                                 1 ;
    build_tip_count_hash( $tree, \%cnt );
    reorder_against_tip_count( $tree, \%cnt, $dir );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $node = reorder_by_tip_count( $node, $cntref, $dir )
#      dir  < 0 for upward branch (big group first),
#           = 0 for no change, and
#           > 0 for downward branch (small group first).
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub reorder_against_tip_count
{
    my ( $node, $cntref, $dir ) = @_;

    my $nd = newick_n_desc( $node );
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip

    #  Reorder this subtree:

    my $dl_ref = newick_desc_ref( $node );
    if    ( $dir > 0 ) {                   #  Big group first
        @$dl_ref = sort { $cntref->{$b} <=> $cntref->{$a} } @$dl_ref;
    }
    elsif ( $dir < 0 ) {                   #  Small group first
        @$dl_ref = sort { $cntref->{$a} <=> $cntref->{$b} } @$dl_ref;
    }

    #  Reorder within descendant subtrees:

    my $step = 0;
    if (abs( $dir ) < 1e5) {
        $dir = 1 - $nd;                              #  Midgroup => as is
    #   $dir = 1 - $nd + ( $dir < 0 ? -0.5 : 0.5 );  #  Midgroup => outward
        $step = 2;
    }

    for ( my $i = 0; $i < $nd; $i++ ) {
        reorder_by_tip_count( $dl_ref->[$i], $cntref, $dir );
        $dir += $step;
    }

    $node;
}


#-------------------------------------------------------------------------------
#  Randomize descendant order at each node (in place).
#
#  $tree = random_order_newick_tree( $tree )
#
#-------------------------------------------------------------------------------
sub random_order_newick_tree
{
    my ( $node ) = @_;

    my $nd = newick_n_desc( $node );
    if ( $nd <  1 ) { return $node }       #  Do nothing to a tip

    #  Reorder this subtree:

    my $dl_ref = newick_desc_ref( $node );
    @$dl_ref = &random_order( @$dl_ref );

    #  Reorder descendants:

    foreach ( @$dl_ref ) { random_order_newick_tree( $_ ) }

    $node;
}


#-------------------------------------------------------------------------------
#  Reroot a tree using method specified by options.
#
#     $newtree = reroot_tree( $tree, \%options )
#
#  Options
#
#     adjacent_to_tip =>  $tip         # root next to named tip (no nodes)
#     adjacent_to_tip =>  $bool        # root next to tip defined by nodes
#     distance        =>  $distance    # distance on path from node1 to node2
#     fraction        =>  $fraction    # fraction of path from node1 to node2
#     midpoint        =>  $bool        # midpoint root tree (no nodes)
#     node            =>  $node_spec   # just one node spec
#     nodes           => \@node_specs  # 0, 1 or 2 node specifiers
#     tip             =>  $tip         # short way to get tip root
#
#  node_spec can be 1, 2 or 3 node labels:
#
#     With 1 label, it is the node with that name (tip or internal)
#     With 2 labels, it is the most recent common ancestor of the 2 named nodes
#     With 3 labels, it is the intersection point of the paths to the 3 nodes
#
#-------------------------------------------------------------------------------
sub reroot_tree
{
    my ( $tree, $opts ) = @_;
    return undef if ! array_ref( $tree );
    $opts ||= {};

    return reroot_newick_to_midpoint_w( $tree ) if $opts->{ midpoint };

    #  All other options require 1 or 2 node specifiers

    my @nodes = array_ref( $opts->{ nodes } ) ? @{ $opts->{ nodes } } : ();
    push @nodes, $opts->{ node } if array_ref( $opts->{ node } );

    foreach ( @nodes )
    {
        next if ( array_ref( $_ ) && ( @$_ > 0 ) && ( @$_ <= 3 ) );
        print STDERR "Bad node specifier passed to gjonewicklib::reroot_tree().\n";
        return $tree;
    }

    my $adj_to_tip = $opts->{ adjacent_to_tip };
    my $distance   = $opts->{ distance };
    my $fraction   = $opts->{ fraction };
    my $tip        = $opts->{ tip };

    if ( defined( $distance ) && @nodes == 2 )
    {
        $distance = 0 if $distance < 0;
        $tree = reroot_newick_at_dist_between_nodes( $tree, @nodes, $distance )
    }
    elsif ( @nodes == 2 )
    {
        $fraction = 0.5 if ! defined( $fraction );
        $fraction = 0   if $fraction < 0;
        $fraction = 1   if $fraction > 1;
        $tree = reroot_newick_between_nodes( $tree, @nodes, $fraction )
    }
    elsif ( $adj_to_tip )
    {
        $adj_to_tip = $nodes[0]->[0] if @nodes == 1 && @{$nodes[0]} == 1;
        $tree = reroot_newick_next_to_tip( $tree, $adj_to_tip );
    }
    elsif ( @nodes == 1 )
    {
        #  Root at node:
        $tree = reroot_newick_to_node( $tree, $nodes[0] );
    }
    elsif ( defined( $tip ) && $tip ne '' )
    {
        #  Root at tip:
        $tree = reroot_newick_to_tip( $tree, $tip );
    }

    return $tree;
}


#-------------------------------------------------------------------------------
#  Reroot a tree to the node that lies at the end of a path.
#
#  $newtree = reroot_newick_by_path( @path )
#
#-------------------------------------------------------------------------------
sub reroot_newick_by_path
{
    my ( $node1, $path1, @rest ) = @_;
    array_ref( $node1 ) || return undef;      #  Always expect a node

    defined( $path1 ) && @rest || return $node1;  #  If no path, we're done

    my $node2 = $rest[0];                     #  Next element in path is node 2
    newick_desc_i( $node1, $path1 ) eq $node2 || return undef;  #  Check link

    #  Remove node 2 from node 1 descendant list.  Could use a simple splice:
    #
    #      splice( @$dl1, $path1-1, 1 );
    #
    #  But the following maintains the cyclic order of the nodes:

    my $dl1 = newick_desc_ref( $node1 );
    my $nd1 = @$dl1;
    if    ( $path1 == 1    ) { shift @$dl1 }
    elsif ( $path1 == $nd1 ) { pop   @$dl1 }
    else                     { @$dl1 = ( @$dl1[ $path1 .. $nd1-1   ]
                                       , @$dl1[ 0      .. $path1-2 ]
                                       )
                             }

    #  Append node 1 to node 2 descendant list (does not alter numbering):

    my $dl2 = newick_desc_ref( $node2 );
    if ( array_ref( $dl2 ) ) { push @$dl2, $node1 }
    else                     { set_newick_desc_list( $node2, $node1 ) }

    #  Move c1 comments from node 1 to node 2:

    my $C11 = newick_c1( $node1 );
    my $C12 = newick_c1( $node2 );
    ! defined( $C11 ) || set_newick_c1( $node1, undef ); #  Remove them from node 1
    if ( $C12 && @$C12 ) {                               #  If node 2 comments and
        if ( $C11 && @$C11 ) { unshift @$C12, @$C11 }    #  Node 1, prefix 1 to 2
    }
    elsif ( $C11 && @$C11 ) { set_newick_c1( $node2, $C11 ) } #  Otherwise move node 1 link

    #  Swap branch lengths and comments for reversal of link direction:

    my $x1 = newick_x( $node1 );
    my $x2 = newick_x( $node2 );
    ! defined( $x1 ) && ! defined ( $x2 ) || set_newick_x( $node1, $x2 );
    ! defined( $x1 ) && ! defined ( $x2 ) || set_newick_x( $node2, $x1 );

    my $c41 = newick_c4( $node1 );
    my $c42 = newick_c4( $node2 );
    ! defined( $c42 ) || ! @$c42 || set_newick_c4( $node1, $c42 );
    ! defined( $c41 ) || ! @$c41 || set_newick_c4( $node2, $c41 );

    my $c51 = newick_c5( $node1 );
    my $c52 = newick_c5( $node2 );
    ! defined( $c52 ) || ! @$c52 || set_newick_c5( $node1, $c52 );
    ! defined( $c51 ) || ! @$c51 || set_newick_c5( $node2, $c51 );

    reroot_newick_by_path( @rest );           #  Node 2 is first element of rest
}


#-------------------------------------------------------------------------------
#  Move root of tree to named tip.
#
#  $newtree = reroot_newick_to_tip( $tree, $tip )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_tip
{
    my ( $tree, $tipname ) = @_;
    reroot_newick_by_path( path_to_tip( $tree, $tipname ) );
}


#-------------------------------------------------------------------------------
#  Move root of tree to be node adjacent to a named tip.
#
#  $newtree = reroot_newick_next_to_tip( $tree, $tip )
#
#-------------------------------------------------------------------------------
sub reroot_newick_next_to_tip
{
    my ( $tree, $tipname ) = @_;
    my @path = path_to_tip( $tree, $tipname );
    @path || return undef;
    @path == 1 ? reroot_newick_by_path( $tree, 1, newick_desc_i( $tree, 1 ) )
               : reroot_newick_by_path( @path[ 0 .. @path-3 ] );
}


#-------------------------------------------------------------------------------
#  Move root of tree to a node, defined by 1 or 3 tip names.
#
#  $newtree = reroot_newick_to_node( $tree, @node )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_node
{
    reroot_newick_by_path( path_to_node( @_ ) );
}


#-------------------------------------------------------------------------------
#  Move root of tree to a node, defined by reference.
#
#  $newtree = reroot_newick_to_node_ref( $tree, $noderef )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_node_ref
{
    my ( $tree, $node ) = @_;
    reroot_newick_by_path( path_to_node_ref( $tree, $node ) );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes:
#
#  $tree = reroot_newick_between_nodes( $tree, $node1, $node2, $fraction )
#
#-------------------------------------------------------------------------------
sub reroot_newick_between_nodes
{
    my ( $tree, $node1, $node2, $fraction ) = @_;
    array_ref( $tree ) or return undef;

    #  Find the paths to the nodes:

    my @path1 = path_to_node( $tree, $node1 ) or return $tree;
    my @path2 = path_to_node( $tree, $node2 ) or return $tree;

    reroot_newick_between_nodes_by_path( \@path1, \@path2, $fraction )
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes:
#
#  $tree = reroot_newick_between_node_refs( $tree, $node1, $node2, $fraction )
#
#-------------------------------------------------------------------------------
sub reroot_newick_between_node_refs
{
    my ( $tree, $node1, $node2, $fraction ) = @_;
    array_ref( $tree ) or return undef;

    #  Find the paths to the nodes:

    my @path1 = path_to_node_ref( $tree, $node1 ) or return $tree;
    my @path2 = path_to_node_ref( $tree, $node2 ) or return $tree;

    reroot_newick_between_nodes_by_path( \@path1, \@path2, $fraction )
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes defined by paths:
#
#  $tree = reroot_newick_between_nodes_by_path( $path1, $path2, $fraction )
#
#-------------------------------------------------------------------------------
sub reroot_newick_between_nodes_by_path
{
    my ( $path1, $path2, $fraction ) = @_;
    array_ref( $path1 ) && array_ref( $path2 ) or return undef;

    $fraction = 0 if ( ! defined( $fraction ) ) || ( $fraction < 0 );
    $fraction = 1 if ( $fraction > 1 );

    my $prefix;
    ( $prefix, $path1, $path2 ) = common_and_unique_paths( $path1, $path2 );

    my $dist1 = ( @$path1 >= 3 ) ? newick_path_length( @$path1 ) : 0;
    my $dist2 = ( @$path2 >= 3 ) ? newick_path_length( @$path2 ) : 0;

    #  Case where there is no length (possibly same node):

    return reroot_newick_by_path( @$prefix, $path1->[0] ) if $dist1 + $dist2 <= 0; 

    my $dist = $fraction * ( $dist1 + $dist2 ) - $dist1;
    my $path = ( $dist <= 0 ) ? $path1 : $path2;
    $dist = abs( $dist );

    #  Descend tree until we reach the insertion branch:

    reroot_newick_at_dist_along_path( $prefix, $path, $dist );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes:
#
#  $tree = reroot_newick_at_dist_between_nodes( $tree, $node1, $node2, $distance )
#
#-------------------------------------------------------------------------------
sub reroot_newick_at_dist_between_nodes
{
    my ( $tree, $node1, $node2, $distance ) = @_;
    array_ref( $tree ) or return undef;

    #  Find the paths to the nodes:

    my @path1 = path_to_node( $tree, $node1 ) or return $tree;
    my @path2 = path_to_node( $tree, $node2 ) or return $tree;

    reroot_newick_at_dist_between_nodes_by_path( \@path1, \@path2, $distance );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes identified by ref:
#
#  $tree = reroot_newick_at_dist_between_node_refs( $tree, $node1, $node2, $distance )
#
#-------------------------------------------------------------------------------
sub reroot_newick_at_dist_between_node_refs
{
    my ( $tree, $node1, $node2, $distance ) = @_;
    array_ref( $tree ) or return undef;

    #  Find the paths to the nodes:

    my @path1 = path_to_node_ref( $tree, $node1 ) or return $tree;
    my @path2 = path_to_node_ref( $tree, $node2 ) or return $tree;

    reroot_newick_at_dist_between_nodes_by_path( \@path1, \@path2, $distance );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes defined by paths:
#
#  $tree = reroot_newick_at_dist_between_nodes_by_path( $path1, $path2, $distance )
#
#-------------------------------------------------------------------------------
sub reroot_newick_at_dist_between_nodes_by_path
{
    my ( $path1, $path2, $distance ) = @_;
    array_ref( $path1 ) && array_ref( $path2 ) or return undef;
    $distance = 0 if ( ! defined( $distance ) ) || ( $distance < 0 );

    my $prefix;
    ( $prefix, $path1, $path2 ) = common_and_unique_paths( $path1, $path2 );

    my $dist1 = ( @$path1 >= 3 ) ? newick_path_length( @$path1 ) : 0;
    my $dist2 = ( @$path2 >= 3 ) ? newick_path_length( @$path2 ) : 0;

    #  Case where there is no length (possibly same node):

    return reroot_newick_by_path( @$prefix, $path1->[0] ) if $dist1 + $dist2 <= 0; 

    my ( $path, $dist );
    if ( $distance < $dist1 )
    {
        $path = $path1;
        $dist = $dist1 - $distance;
    }
    else
    {
        $path = $path2;
        $dist = $distance - $dist1;
    }

    #  Descend tree until we reach the insertion branch:

    reroot_newick_at_dist_along_path( $prefix, $path, $dist );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree along the path between 2 nodes defined by paths:
#
#  ( \@common, \@unique1, \@unique2 ) = common_and_unique_paths( \@path1, \@path2 )
#
#-------------------------------------------------------------------------------
sub common_and_unique_paths
{
    my ( $path1, $path2 ) = @_;

    my @path1 = @$path1;
    my @path2 = @$path2;

    #  Trim the common prefix, saving it:

    my $i = 1;
    my $imax = min( scalar @path1, scalar @path2 );
    while ( ( $i < $imax ) && ( $path1[$i] == $path2[$i] ) ) { $i += 2 }

    my @prefix = ();
    if ( $i > 1 ) { @prefix = splice( @path1, 0, $i-1 ); splice( @path2, 0, $i-1 ) }

    ( \@prefix, \@path1, \@path2 );
}


#-------------------------------------------------------------------------------
#  Reroot a newick tree at a distance from the most ancestral node along a path:
#
#  $tree = reroot_newick_at_dist_along_path( \@prefix, \@path, $distance )
#
#     -   n1              n1
#     |  /  \            /  \
#     |      \ x2            \ x2
#     |       \               \
#     | dist   n2              n2
#     |       /  \            /  \ x23 = dist - x2
#     |           \               \
#     -----------  \ x3  --------  n23
#                   \             /  \ x3' = x3 - x23
#                    n3               n3
#                   /  \             /  \
#
#-------------------------------------------------------------------------------
sub reroot_newick_at_dist_along_path
{
    my ( $prefix, $path, $dist ) = @_;
    array_ref( $prefix ) or return undef;
    array_ref( $path )   or return $prefix->[0];
    defined( $dist )     or $dist = 0;

    my @prefix = @$prefix;
    my @path   = @$path;

    #  Descend tree until we reach the insertion branch:

    my $x = ( @path > 2 ) ? newick_x( $path[2] ) : 0;
    while ( ( @path > 4 ) && ( $dist > $x ) )
    {
        $dist -= $x;
        push @prefix, splice( @path, 0, 2 );
        $x = newick_x( $path[2] );
    }
    $dist = $x if ( $dist > $x );

    #  Insert the new node:

    my $newnode = [ [ $path[2] ], undef, $dist ];
    set_newick_desc_i( $path[0], $path[1], $newnode );
    set_newick_x( $path[2], $x - $dist );

    #  We can now build the path from root to the new node

    reroot_newick_by_path( @prefix, @path[0,1], $newnode );
}


#-------------------------------------------------------------------------------
#  Move root of tree to an approximate midpoint.
#
#  $newtree = reroot_newick_to_approx_midpoint( $tree )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_approx_midpoint
{
    my ( $tree ) = @_;

    #  Compile average tip to node distances assending

    my $dists1 = average_to_tips_1( $tree );

    #  Compile average tip to node distances descending, returning midpoint
    #  cadidates as a list of [ $node1, $node2, $fraction ]

    my @mids = average_to_tips_2( $dists1, undef, undef );

    #  Reroot to first midpoint candidate

    return $tree if ! @mids;
    my ( $node1, $node2, $fraction ) = @{ $mids[0] };
    reroot_newick_to_node_ref( $tree, $fraction >= 0.5 ? $node2 : $node1 );
}


#-------------------------------------------------------------------------------
#  Move root of tree to a midpoint.
#
#  $newtree = reroot_newick_to_midpoint( $tree )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_midpoint
{
    my ( $tree ) = @_;

    #  Compile average tip to node distances assending

    my $dists1 = average_to_tips_1( $tree );

    #  Compile average tip to node distances descending, returning midpoint
    #  [ $node1, $node2, $fraction ]

    my @mids = average_to_tips_2( $dists1, undef, undef );

    @mids ? reroot_newick_between_node_refs( $tree, @{ $mids[0] } ) : $tree;
}


#-------------------------------------------------------------------------------
#  Compile average tip to node distances assending
#-------------------------------------------------------------------------------
sub average_to_tips_1
{
    my ( $node ) = @_;

    my @desc_dists = map { average_to_tips_1( $_ ) } newick_desc_list( $node );
    my $x_below = 0;
    if ( @desc_dists )
    {
        foreach ( @desc_dists ) { $x_below += $_->[0] }
        $x_below /= @desc_dists;
    }

    my $x = newick_x( $node ) || 0;
    my $x_net = $x_below + $x;

    [ $x_net, $x, $x_below, [ @desc_dists ], $node ]
}


#-------------------------------------------------------------------------------
#  Compile average tip to node distances descending, returning midpoint as
#  [ $node1, $node2, $fraction_of_dist_between ]
#-------------------------------------------------------------------------------
sub average_to_tips_2
{
    my ( $dists1, $x_above, $anc_node ) = @_;
    my ( undef, $x, $x_below, $desc_list, $node ) = @$dists1;

    #  Are we done?  Root is in this node's branch, or "above"?

    my @mids = ();
    if ( defined( $x_above ) && ( ( $x_above + $x ) >= $x_below ) )
    {
        #  At this point the root can only be in this node's branch,
        #  or "above" it in the current rooting of the tree (which
        #  would mean that the midpoint is actually down a different
        #  path from the root of the current tree).
        #
        #  Is the root in the current branch?

        if ( ( $x_below + $x ) >= $x_above )
        {
            #  We will need to make a new node for the root, $fract of
            #  the way from $node to $anc_node:
            my $fract = ( $x > 0 ) ? 0.5 * ( ( $x_above - $x_below ) / $x + 1 )
                                   : 0.5;
            push @mids, [ $node, $anc_node, $fract ];
        }
    }

    #  The root might be somewhere below this node:

    my $n_1      =   @$desc_list - ( $anc_node ? 0 : 1 );
    my $ttl_dist = ( @$desc_list * $x_below ) + ( defined( $x_above ) ? ( $x_above + $x ) : 0 );

    foreach ( @$desc_list )
    {
        #  If input tree is tip_rooted, $n-1 can be 0, so:

        my $above2 = $n_1 ? ( ( $ttl_dist - $_->[0] ) / $n_1 ) : 0;
        push @mids, average_to_tips_2( $_, $above2, $node );
    }

    return @mids;
}


#-------------------------------------------------------------------------------
#  Move root of tree to an approximate midpoint.  Weight by tips.
#
#  $newtree = reroot_newick_to_approx_midpoint_w( $tree )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_approx_midpoint_w
{
    my ( $tree ) = @_;
    array_ref( $tree ) or return undef;

    #  Compile average tip to node distances assending from tips

    my $dists1 = average_to_tips_1_w( $tree );

    #  Compile average tip to node distances descending, returning midpoints

    my @mids = average_to_tips_2_w( $dists1, undef, undef, undef );

    #  Reroot to first midpoint candidate

    return $tree if ! @mids;
    my ( $node1, $node2, $fraction ) = @{ $mids[0] };
    reroot_newick_to_node_ref( $tree, $fraction >= 0.5 ? $node2 : $node1 );
}


#-------------------------------------------------------------------------------
#  Move root of tree to an approximate midpoint.  Weight by tips.
#
#  $newtree = reroot_newick_to_midpoint_w( $tree )
#
#-------------------------------------------------------------------------------
sub reroot_newick_to_midpoint_w
{
    my ( $tree ) = @_;
    array_ref( $tree ) or return ();

    #  Compile average tip to node distances assending

    my $dists1 = average_to_tips_1_w( $tree );

    #  Compile average tip to node distances descending, returning midpoint node

    my @mids = average_to_tips_2_w( $dists1, undef, undef, undef );

    #  Reroot at first candidate midpoint

    @mids ? reroot_newick_between_node_refs( $tree, @{ $mids[0] } ) : $tree;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub average_to_tips_1_w
{
    my ( $node ) = @_;

    my @desc_dists = map { average_to_tips_1_w( $_ ) } newick_desc_list( $node );
    my $x_below = 0;
    my $n_below = 1;
    if ( @desc_dists )
    {
        $n_below = 0;
        my $n;
        foreach ( @desc_dists )
        {
            $n_below += $n = $_->[1];
            $x_below += $n * $_->[0];
        }
        $x_below /= $n_below;
    }

    my $x = newick_x( $node ) || 0;
    my $x_net = $x_below + $x;

    [ $x_net, $n_below, $x, $x_below, [ @desc_dists ], $node ]
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub average_to_tips_2_w
{
    my ( $dists1, $x_above, $n_above, $anc_node ) = @_;
    my ( undef, $n_below, $x, $x_below, $desc_list, $node ) = @$dists1;

    #  Are we done?  Root is in this node's branch, or "above"?

    my @mids = ();
    if ( defined( $x_above ) && ( ( $x_above + $x ) >= $x_below ) )
    {
        #  At this point the root can only be in this node's branch,
        #  or "above" it in the current rooting of the tree (which
        #  would mean that the midpoint is actually down a different
        #  path from the root of the current tree).
        #
        #  Is their a root in the current branch?

        if ( ( $x_below + $x ) >= $x_above )
        {
            #  We will need to make a new node for the root, $fract of
            #  the way from $node to $anc_node:
            my $fract = ( $x > 0 ) ? 0.5 * ( ( $x_above - $x_below ) / $x + 1 )
                                   : 0.5;
            push @mids, [ $node, $anc_node, $fract ];
        }
    }

    #  The root must be some where below this node:

    $n_above ||= 0;
    my $n = $n_above + $n_below;
    my $ttl_w_dist = ( $n_below * $x_below )
                   + ( defined( $x_above ) ? $n_above * ( $x_above + $x ) : 0 );

    foreach ( @$desc_list )
    {
        my $n_2      = $_->[1];    # n in subtree
        my $n_above2 = $n - $n_2;  # tip rooted has 1 above

        #  If input tree is tip_rooted, $n_above2 can be 0, so:

        my $x_above2 = $n_above2 ? ( ( $ttl_w_dist - $n_2 * $_->[0] ) / $n_above2 )
                                 : 0;
        push @mids, average_to_tips_2_w( $_, $x_above2, $n_above2 || 1, $node );
    }

    return @mids;
}


#-------------------------------------------------------------------------------
#  Move root of tree from tip to adjacent node.
#
#  $newtree = uproot_tip_rooted_newick( $tree )
#
#-------------------------------------------------------------------------------
sub uproot_tip_rooted_newick
{
    my ( $node ) = @_;
    newick_is_tip_rooted( $node ) || return $node;

    #  Path to the sole descendant:

    reroot_newick_by_path( $node, 1, newick_desc_i( $node, 1 ) );
}


#-------------------------------------------------------------------------------
#  Remove root bifurcation.
#
#  Root node label, label comment and descendant list comment are discarded.
#
#  $newtree = uproot_newick( $tree )
#
#-------------------------------------------------------------------------------
sub uproot_newick
{
    my ( $node0 ) = @_;
    newick_is_rooted( $node0 ) || return $node0;

    my ( $node1, $node2 ) = newick_desc_list( $node0 );

    #  Ensure that node1 has at least 1 descendant

    if    ( newick_n_desc( $node1 ) ) {
        push @{ newick_desc_ref( $node1 ) }, $node2;    #  Add node2 to descend list
    }

    #  Or node2 has at least 1 descendant

    elsif ( newick_n_desc( $node2 ) ) {
        unshift @{ newick_desc_ref( $node2 ) }, $node1;   #  Add node1 to descend list
        ( $node1, $node2 ) = ( $node2, $node1 );        #  And reverse labels
    }

    #  We could make this into a tip rooted tree, but for now:

    else { return $node0 }

    #  Prefix node1 branch to that of node2:

    add_to_newick_branch( $node2, $node1 );
    set_newick_x( $node1, undef );

    #  Tree prefix comment lists (as references):

    my $C10 = newick_c1( $node0 );
    my $C11 = newick_c1( $node1 );
    if ( $C11 && @$C11 ) {
        if ( $C10 && @$C10 ) { unshift @$C11, @$C10 } #  Prefix to node1 comments
    }
    elsif ( $C10 && @$C10 ) {
        set_newick_c1( $node1, $C10 )          #  Or move node0 comments to node1
    }

    $node1;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Prefix branch of node2 to that of node1:
#
#  $node1 = add_to_newick_branch( $node1, $node2 )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub add_to_newick_branch
{
    my ( $node1, $node2 ) = @_;
    array_ref( $node1 ) || die "add_to_newick_branch: arg 1 not array ref\n";
    array_ref( $node2 ) || die "add_to_newick_branch: arg 2 not array ref\n";

    #  Node structure template:
    #     my ( $DL, $L, $X, $C1, $C2, $C3, $C4, $C5 ) = @$node;

    #  Fix branch lengths for joining of two branches:

    set_newick_x( $node1, newick_x( $node1 ) + newick_x( $node2 ) );

    #  Merge branch length comments:

    my $C41 = newick_c4( $node1 );  #  Ref to node1 C4
    my $C42 = newick_c4( $node2 );  #  Ref to node2 C4
    if ( $C41 && @$C41 ) {
        if ( $C42 && @$C42 ) { unshift @$C41, @$C42 }         #  Add node2 comment
    }
    elsif ( $C42 && @$C42 ) { set_newick_c4( $node1, $C42 ) } #  Or move node1 comment

    my $C51 = newick_c5( $node1 );  #  Ref to node1 C5
    my $C52 = newick_c5( $node2 );  #  Ref to node2 C5
    if ( $C51 && @$C51 ) {
        if ( $C52 && @$C52 ) { unshift @$C51, @$C52 }         #  Add node2 comment
    }
    elsif ( $C52 && @$C52 ) { set_newick_c5( $node1, $C52 ) } #  Or move node1 comment

    $node1;
}


#-------------------------------------------------------------------------------
#  Collapse zero-length branches to make multifurcation.  The original tree
#  is modified.
#
#  $tree = collapse_zero_length_branches( $tree )
#  $tree = collapse_zero_length_branches( $tree, $not_root )
#
#-------------------------------------------------------------------------------
sub collapse_zero_length_branches
{
    my ( $tree, $not_root ) = @_;
    array_ref( $tree ) || return undef;

    my @desc = newick_desc_list( $tree );
    @desc or return ( $tree );              # Cannot collapse terminal branch

    #  Analyze descendants:

    $not_root ||= 0;
    my @new_desc = ();
    my $changed = 0;
    foreach ( @desc )
    {
        my ( undef, @to_add ) = collapse_zero_length_branches( $_, $not_root+1 );
        if ( @to_add )
        {
            push @new_desc, @to_add;
            $changed = 1;
        }
        else
        {
            push @new_desc, $_;
        }
    }
    set_newick_desc_ref( $tree, [ @new_desc ] ) if $changed;

    #  Collapse if not root, not tip and zero (or negative) branch:

    my $collapse = $not_root && @new_desc && ( newick_x( $tree ) <= 0 ) ? 1 : 0;
    ( $tree, ( $collapse ? @new_desc : () ) );
}

#-------------------------------------------------------------------------------
#  Add a subtree to a newick tree node:
#
#  $node = newick_insert_at_node( $node, $subtree )
#
#-------------------------------------------------------------------------------
sub newick_insert_at_node
{
    my ( $node, $subtree ) = @_;
    array_ref( $node ) && array_ref( $subtree ) or return undef;

    #  We could check validity of trees, but ....

    my $dl = newick_desc_ref( $node );
    if ( array_ref( $dl ) )
    {
        push @$dl, $subtree;
    }
    else
    {
        set_newick_desc_ref( $node, [ $subtree ] );
    }
    return $node;
}


#-------------------------------------------------------------------------------
#  Insert a subtree into a newick tree along the path between 2 nodes:
#
#  $tree = newick_insert_between_nodes( $tree, $subtree, $node1, $node2, $fraction )
#
#-------------------------------------------------------------------------------
sub newick_insert_between_nodes
{
    my ( $tree, $subtree, $node1, $node2, $fraction ) = @_;
    array_ref( $tree ) && array_ref( $subtree ) or return undef;
    $fraction >= 0 && $fraction <= 1 or return undef;

    #  Find the paths to the nodes:

    my @path1 = path_to_node( $tree, $node1 ) or return undef;
    my @path2 = path_to_node( $tree, $node2 ) or return undef;

    #  Trim the common prefix:

    while ( $path1[1] == $path2[1] )
    {
        splice( @path1, 0, 2 );
        splice( @path2, 0, 2 );
    }

    my ( @path, $dist );
    if    ( @path1 < 3 )
    {
        @path2 >= 3 or return undef;              # node1 = node2
        $dist = $fraction * newick_path_length( @path2 );
        @path = @path2;
    }
    elsif ( @path2 < 3 )
    {
        $dist = ( 1 - $fraction ) * newick_path_length( @path1 );
        @path = @path1;
    }
    else
    {
        my $dist1 = newick_path_length( @path1 );
        my $dist2 = newick_path_length( @path2 );
        $dist = $fraction * ( $dist1 + $dist2 ) - $dist1;
        @path = ( $dist <= 0 ) ? @path1 : @path2;
        $dist = abs( $dist );
    }

    #  Descend tree until we reach the insertion branch:

    my $x;
    while ( ( $dist > ( $x = newick_x( $path[2] ) ) ) && ( @path > 3 ) )
    {
        $dist -= $x;
        splice( @path, 0, 2 );
    }

    #  Insert the new node:

    set_newick_desc_i( $path[0], $path[1], [ [ $path[2], $subtree ], undef, $dist ] );
    set_newick_x( $path[2], ( ( $x > $dist ) ? ( $x - $dist ) : 0 ) );

    return $tree;
}


#-------------------------------------------------------------------------------
#  Prune one or more tips from a tree:
#     Caveat:  if one tip is listed, the original tree is modified.
#              if more than one tip is listed, a copy of the tree is returned
#                   (even if it is just listing the same tip twice!).
#
#  $newtree = prune_from_newick( $tree,  $tip  )
#  $newtree = prune_from_newick( $tree,  @tips )
#  $newtree = prune_from_newick( $tree, \@tips )
#
#-------------------------------------------------------------------------------
sub prune_from_newick
{
    my ( $tr, @tips ) = @_;
    if ( @tips == 1 && ref( $tips[0] ) eq "ARRAY" ) { @tips = @{ $tips[0] } }

    if ( @tips == 0 ) { return $tr }
    if ( @tips == 1 ) { return prune_1_from_newick( $tr, @tips ) }

    my %del  = map  { ( $_, 1 ) } @tips;
    my @keep = grep { ! $del{ $_ } } newick_tip_list( $tr );
    newick_subtree( $tr, @keep );
}


#-------------------------------------------------------------------------------
#  Prune a tip from a tree:
#
#  $newtree = prune_1_from_newick( $tree, $tip )
#
#-------------------------------------------------------------------------------
sub prune_1_from_newick
{
    my ( $tr, $tip ) = @_;
    my @path = path_to_tip( $tr, $tip );
    if ( @path < 3 ) { return $tr }

    my $node = $path[-1];  #  Node with the tip
    my $i1   = $path[-2];  #  Descendant number of node in ancestor desc list
    my $anc1 = $path[-3];  #  Ancestor of node
    my $nd1  = newick_n_desc( $anc1 );  #  Number of descendants of ancestor
    my $anc2 = ( @path >= 5 ) ? $path[-5] : undef; # Ancestor of anc1

    # dump_tree( $node );
    # print STDERR "i1 = $i1\n";
    # dump_tree( $anc1 );
    # print STDERR "nd1 = $nd1\n";
    # defined( $anc2 ) && dump_tree( $anc2 );

    if ( $nd1 > 3 || ( $anc2 && $nd1 > 2 ) ) {   # Tip joins at multifurcation
        splice( @{ $anc1->[0] }, $i1-1, 1 );     #    delete the descendant
    }

    elsif ( $anc2 ) {                            # Tip joins at internal bifurcation
        my $sis = newick_desc_i( $anc1, 3-$i1 );     # find sister node
        add_to_newick_branch( $sis, $anc1 );         # combine internal branches
        set_newick_desc_i( $anc2, $path[-4], $sis ); # remove $anc1
    }

    elsif ( $nd1 == 2) {                         # Tip joins bifurcating root node
        my $sis = newick_desc_i( $anc1, 3-$i1 ); #    find sister node
        $sis->[1] = $anc1->[1] if ! $sis->[1] && $anc1->[1];  # root label
        $sis->[2] = undef;                                    # root branch len
        $sis->[3] = $anc1->[3] if ! $sis->[3] && $anc1->[3];  # tree comment
        $sis->[4] = $anc1->[4] if ! $sis->[4] && $anc1->[4];  # desc list comment
        $sis->[5] = $anc1->[5] if ! $sis->[5] && $anc1->[5];  # label comment
        $sis->[6] = undef      if   $sis->[6];   #    root branch comment
        $sis->[7] = undef      if   $sis->[7];   #    root branch comment
        $tr = $sis;                              #    sister is new root
    }

    elsif ( $nd1 == 3 ) {                        # Tip joins trifurcating root:
        splice( @{ $anc1->[0] }, $i1-1, 1 );     #    delete the descendant, and
        $tr = uproot_newick( $tr );              #    fix the rooting
    }

    else {
        return undef;
    }

    return $tr;
}


#-------------------------------------------------------------------------------
#  Produce a potentially rooted subtree with the desired tips:
#
#     Except for (some) tip nodes, the tree produced is a copy.
#     There is no check that requested tips exist.
#
#  $newtree = rooted_newick_subtree( $tree,  @tips )
#  $newtree = rooted_newick_subtree( $tree, \@tips )
#
#-------------------------------------------------------------------------------
sub rooted_newick_subtree
{
    my ( $tr, @tips ) = @_;
    if ( @tips == 1 && ref( $tips[0] ) eq "ARRAY" ) { @tips = @{ $tips[0] } }

    if ( @tips < 2 ) { return undef }
    my $keephash = { map { ( $_, 1 ) } @tips };
    my $tr2 = subtree1( $tr, $keephash );
    $tr2->[2] = undef if $tr2;                   # undef root branch length
    $tr2;
}


#-------------------------------------------------------------------------------
#  Produce a subtree with the desired tips:
#
#     Except for (some) tip nodes, the tree produced is a copy.
#     There is no check that requested tips exist.
#
#  $newtree = newick_subtree( $tree,  @tips )
#  $newtree = newick_subtree( $tree, \@tips )
#
#-------------------------------------------------------------------------------
sub newick_subtree
{
    my ( $tr, @tips ) = @_;
    if ( @tips == 1 && ref( $tips[0] ) eq "ARRAY" ) { @tips = @{ $tips[0] } }

    if ( @tips < 2 ) { return undef }
    my $was_rooted = newick_is_rooted( $tr );
    my $keephash = { map { ( $_, 1 ) } @tips };
    my $tr2 = subtree1( $tr, $keephash );
    $tr2 = uproot_newick( $tr2 ) if ! $was_rooted && newick_is_rooted( $tr2 );
    $tr2->[2] = undef if $tr2;                   # undef root branch length
    $tr2;
}


sub subtree1
{
    my ( $tr, $keep ) = @_;
    my @desc1 = newick_desc_list( $tr );

    #  Is this a tip, and is it in the keep list?

    if ( @desc1 < 1 ) {
        return ( $keep->{ newick_lbl( $tr ) } ) ? $tr : undef;
    }

    #  Internal node: analyze the descendants:

    my @desc2 = ();
    foreach ( @desc1 ) {
        my $desc = subtree1( $_, $keep );
        if ( $desc && @$desc ) { push @desc2, $desc }
    }

    if ( @desc2 == 0 ) { return undef }
    if ( @desc2 >  1 ) { return [ \@desc2, @$tr[ 1 .. @$tr - 1 ] ] }

    #  Exactly 1 descendant

    my $desc = $desc2[ 0 ];
    my @nn = ( $desc->[0],
               $desc->[1] ? $desc->[1] : $tr->[1],
               defined( $tr->[2] ) ? $desc->[2] + $tr->[2] : undef
             );

    #  Merge comments (only recreating the ones that existed):

    if ( $tr->[3] && @{$tr->[3]} || $desc->[3] && @{$desc->[3]} ) {
        $nn[3] = [ $tr->[3] ? @{$tr->[3]} : (), $desc->[3] ? @{$desc->[3]} : () ];
    }
    if ( $tr->[4] && @{$tr->[4]} || $desc->[4] && @{$desc->[4]} ) {
        $nn[4] = [ $tr->[4] ? @{$tr->[4]} : (), $desc->[4] ? @{$desc->[4]} : () ];
    }
    if ( $tr->[5] && @{$tr->[5]} || $desc->[5] && @{$desc->[5]} ) {
        $nn[5] = [ $tr->[5] ? @{$tr->[5]} : (), $desc->[5] ? @{$desc->[5]} : () ];
    }
    if ( $tr->[6] && @{$tr->[6]} || $desc->[6] && @{$desc->[6]} ) {
        $nn[6] = [ $tr->[6] ? @{$tr->[6]} : (), $desc->[6] ? @{$desc->[6]} : () ];
    }
    if ( $tr->[7] && @{$tr->[7]} || $desc->[7] && @{$desc->[7]} ) {
        $nn[7] = [ $tr->[7] ? @{$tr->[7]} : (), $desc->[7] ? @{$desc->[7]} : () ];
    }

    return \@nn;
}


#-------------------------------------------------------------------------------
#  The smallest subtree of rooted tree that includes @tips:
#
#    $node = newick_covering_subtree( $tree,  @tips )
#    $node = newick_covering_subtree( $tree, \@tips )
#
#-------------------------------------------------------------------------------

sub newick_covering_subtree
{
    my $tree = shift;
    my %tips = map { $_ => 1 } ( ( ref( $_[0] ) eq 'ARRAY' ) ? @{ $_[0] } : @_ );

    #  Return smallest covering node, if any:

    ( newick_covering_subtree( $tree, \%tips ) )[ 0 ];
}


sub newick_covering_subtree_1
{
    my ( $node, $tips ) = @_;
    my $n_cover = 0;
    my @desc = newick_desc_list( $node );
    if ( @desc )
    {
        foreach ( @desc )
        {
            my ( $subtree, $n ) = newick_covering_subtree_1( $_, $tips );
            return ( $subtree, $n ) if $subtree;
            $n_cover += $n;
        }
    }
    elsif ( $tips->{ newick_lbl( $node ) } )
    {
        $n_cover++;
    }

    #  If all tips are covered, return node

    ( $n_cover == keys %$tips ) ? ( $node, $n_cover ) : ( undef, $n_cover );
}


#===============================================================================
#
#  Representative subtrees
#
#===============================================================================
#  Find subtree of size n representating vicinity of the root:
#
#   $subtree = root_neighborhood_representative_tree( $tree, $n, \%tip_priority )
#   $subtree = root_neighborhood_representative_tree( $tree, $n )
#
#  Note that if $tree is rooted, then the subtree will also be.  This can have
#  consequences on downstream programs.
#-------------------------------------------------------------------------------
sub root_neighborhood_representative_tree
{
    my ( $tree, $n, $tip_priority ) = @_;
    array_ref( $tree ) && ( $n >= 2 ) or return undef;
    if ( newick_tip_count( $tree ) <= $n ) { return $tree }

    $tip_priority ||= default_tip_priority( $tree );
    my @tips = map { representative_tip_of_newick_node( $_, $tip_priority ) }
               root_proximal_newick_subtrees( $tree, $n );

    newick_subtree( copy_newick_tree( $tree ), \@tips );
}


#-------------------------------------------------------------------------------
#  Find n tips to represent tree lineages in vicinity of another tip.
#  Default tip priority is short total branch length.
#
#  \@tips = root_neighborhood_representative_tips( $tree, $n, \%tip_priority )
#   @tips = root_neighborhood_representative_tips( $tree, $n, \%tip_priority )
#  \@tips = root_neighborhood_representative_tips( $tree, $n )
#   @tips = root_neighborhood_representative_tips( $tree, $n )
#
#-------------------------------------------------------------------------------
sub root_neighborhood_representative_tips
{
    my ( $tree, $n, $tip_priority ) = @_;
    array_ref( $tree ) && ( $n >= 2 ) or return undef;

    my @tips;
    if ( newick_tip_count( $tree ) <= $n )
    {
        @tips = newick_tip_list( $tree );
    }
    else
    {
        $tip_priority ||= default_tip_priority( $tree );
        @tips = map { representative_tip_of_newick_node( $_, $tip_priority ) }
                root_proximal_newick_subtrees( $tree, $n );
    }

    wantarray ? @tips : \@tips;
}


#-------------------------------------------------------------------------------
#  Find subtree of size n representating vicinity of a tip:
#
#   $subtree = tip_neighborhood_representative_tree( $tree, $tip, $n, \%tip_priority )
#   $subtree = tip_neighborhood_representative_tree( $tree, $tip, $n )
#
#-------------------------------------------------------------------------------
sub tip_neighborhood_representative_tree
{
    my ( $tree, $tip, $n, $tip_priority ) = @_;
    array_ref( $tree ) && $tip && ( $n >= 2 ) or return undef;
    newick_tip_in_tree( $tree, $tip ) or return undef;

    my $tree1 = copy_newick_tree( $tree );
    if ( newick_tip_count( $tree1 ) - 1 <= $n )
    {
        return prune_from_newick( $tree1, $tip )
    }

    $tree1 = reroot_newick_to_tip( $tree1, $tip );
    $tree1 = newick_desc_i( $tree1, 1 );        # Node immediately below tip
    my @tips = root_neighborhood_representative_tips( $tree1, $n, $tip_priority );
    newick_subtree( copy_newick_tree( $tree ), \@tips );
}


#-------------------------------------------------------------------------------
#  Find n tips to represent tree lineages in vicinity of another tip.
#  Default tip priority is short total branch length.
#
#  \@tips = tip_neighborhood_representative_tips( $tree, $tip, $n, \%tip_priority )
#   @tips = tip_neighborhood_representative_tips( $tree, $tip, $n, \%tip_priority )
#  \@tips = tip_neighborhood_representative_tips( $tree, $tip, $n )
#   @tips = tip_neighborhood_representative_tips( $tree, $tip, $n )
#
#-------------------------------------------------------------------------------
sub tip_neighborhood_representative_tips
{
    my ( $tree, $tip, $n, $tip_priority ) = @_;
    array_ref( $tree ) && $tip && ( $n >= 2 ) or return undef;
    newick_tip_in_tree( $tree, $tip ) or return undef;

    my @tips = newick_tip_list( $tree );
    if ( newick_tip_count( $tree ) - 1 <= $n )
    {
        @tips = grep { $_ ne $tip } @tips;
    }
    else
    {
        my $tree1 = copy_newick_tree( $tree );
        $tree1 = reroot_newick_to_tip( $tree1, $tip );
        $tree1 = newick_desc_i( $tree1, 1 );        # Node immediately below tip
        @tips = root_neighborhood_representative_tips( $tree1, $n, $tip_priority );
    }

    wantarray ? @tips : \@tips;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Anonymous hash of the negative distance from root to each tip:
#
#   \%tip_priority = default_tip_priority( $tree )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub default_tip_priority
{
    my ( $tree ) = @_;
    my $tip_distances = newick_tip_distances( $tree ) || {};
    return { map { $_ => -$tip_distances->{$_} } keys %$tip_distances };
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Select a tip from a subtree base on a priority value:
#
#    $tip = representative_tip_of_newick_node( $node, \%tip_priority )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub representative_tip_of_newick_node
{
    my ( $node, $tip_priority ) = @_;
    my ( $tip ) = sort { $b->[1] <=> $a->[1] }   # The best
                  map  { [ $_, $tip_priority->{ $_ } ] }
                  newick_tip_list( $node );
    $tip->[0];                                   # Label from label-priority pair
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Find n subtrees focused around the root of a tree.  Typically each will
#  then be reduced to a single tip to make a representative tree:
#
#   @subtrees = root_proximal_newick_subtrees( $tree, $n )
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub root_proximal_newick_subtrees
{
    my ( $tree, $n ) = @_;
    my $node_start_end = newick_branch_intervals( $tree );
    n_representative_branches( $n, $node_start_end );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#   @node_start_end = newick_branch_intervals( $tree )
#  \@node_start_end = newick_branch_intervals( $tree )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub newick_branch_intervals
{
    my ( $node, $parent_x ) = @_;
    $parent_x ||= 0;
    my ( $desc, undef, $dx ) = @$node;
    my $x = $parent_x + $dx;
    my $interval = [ $node, $parent_x, $desc && @$desc ? $x : 1e100 ];
    my @intervals = ( $interval,
                      map { &newick_branch_intervals( $_, $x ) } @$desc
                    );
    return wantarray ? @intervals : \@intervals;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#   @ids = n_representative_branches( $n,  @id_start_end )
#   @ids = n_representative_branches( $n, \@id_start_end )
#  \@ids = n_representative_branches( $n,  @id_start_end )
#  \@ids = n_representative_branches( $n, \@id_start_end )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub n_representative_branches
{
    my $n = shift;
    #  Sort intervals by start point:
    my @unprocessed = sort { $a->[1] <=> $b->[1] }
                      ( @_ == 1 ) ? @{ $_[0] } : @_;
    my @active = ();
    my ( $interval, $current_point );
    foreach $interval ( @unprocessed )
    {
        $current_point = $interval->[1];
        #  Filter out intervals that have ended.  This is N**2 in the number
        #  of representatives.  Fixing this would require maintaining a sorted
        #  active list.
        @active = grep { $_->[2] > $current_point } @active;
        push @active, $interval;
        last if ( @active >= $n );
    }

    my @ids = map { $_->[0] } @active;
    return wantarray() ? @ids : \@ids;
}


#===============================================================================
#  Random trees
#===============================================================================
#
#   $tree = random_equibranch_tree(  @tips, \%options )
#   $tree = random_equibranch_tree( \@tips, \%options )
#   $tree = random_equibranch_tree(  @tips )
#   $tree = random_equibranch_tree( \@tips )
#
#  Options:
#
#     length => $branch_length   # D = 1
#
#-------------------------------------------------------------------------------
sub random_equibranch_tree
{
    my $opts = $_[ 0] && ref $_[ 0] eq 'HASH' ? shift
             : $_[-1] && ref $_[-1] eq 'HASH' ? pop
             :                                  {};
    return undef if ! defined $_[0];

    my @tips = ref $_[0] ? @{ $_[0] } : @_;
    return undef if @tips < 2;

    my $len = $opts->{ length } ||= 1;

    if ( @tips == 2 )
    {
        return [ [ map { [ [], $_, $len ] } @tips ], undef, 0 ];
    }

    my $tree = [ [ ], undef, 0 ];

    my @links;  # \$anc_dl[i], i.e. a reference to an element in a descendent list

    my $anc_dl = $tree->[0];
    foreach my $tip ( splice( @tips, 0, 3 ) )
    {
        my $node = [ [], $tip, $len ];
        push @$anc_dl, $node;
        push @links, \$anc_dl->[-1];  #  Ref to the just added descendent list entry
    }

    foreach my $tip ( @tips )
    {
        my $link    = $links[ int( rand( scalar @links ) ) ];
        my $newtip  = [ [], $tip, $len ];
        my $new_dl  = [ $$link, $newtip ];
        my $newnode = [ $new_dl, undef, $len ];
        $$link = $newnode;
        push @links, \$new_dl->[0], \$new_dl->[1]
    }

    return $tree;
}


#-------------------------------------------------------------------------------
#
#   $tree = random_ultrametric_tree(  @tips, \%options )
#   $tree = random_ultrametric_tree( \@tips, \%options )
#   $tree = random_ultrametric_tree(  @tips )
#   $tree = random_ultrametric_tree( \@tips )
#
#  Options:
#
#     depth => $root_to_tip_dist   # D = 1
#
#-------------------------------------------------------------------------------
sub random_ultrametric_tree
{
    my $opts = $_[ 0] && ref $_[ 0] eq 'HASH' ? shift
             : $_[-1] && ref $_[-1] eq 'HASH' ? pop
             :                                  {};
    return undef if ! defined $_[0];

    my @tips = ref $_[0] ? @{ $_[0] } : @_;
    return undef if @tips < 2;

    my $d2tip = $opts->{ depth } ||= 1;

    #  Random tip addition order (for rooted tree it matters):

    @tips = sort { rand() <=> 0.5 } @tips;
    my $tree = [ [ ], undef, 0 ];

    my $subtree_size = { $tree => 0 };  # total branch length of each subtree

    #  We start with root bifurcation:

    foreach my $tip ( splice( @tips, 0, 2 ) )
    {
        my $node = [ [], $tip, $d2tip ];
        push @{ $tree->[0] }, $node;
        $subtree_size->{ $node }  = $d2tip;
        $subtree_size->{ $tree } += $d2tip;
    }

    #  Add each remaining tip at $pos, measured along the contour length
    #  of the tree (with no retracing along branches).

    foreach my $tip ( @tips )
    {
        my $pos = rand( $subtree_size->{ $tree } );
        random_add_to_ultrametric_tree( $tree, $tip, $subtree_size, $pos, $d2tip );
    }

    return $tree;
}


sub random_add_to_ultrametric_tree
{
    my ( $node, $tip, $subtree_size, $pos, $d2tip ) = @_;
    $node && $node->[0] && ref $node->[0] eq 'ARRAY' or die "Bad tree node passed to random_add_to_ultrametric_tree().\n";

    # Find the descendent line that it goes in:

    my $i;
    my $dl = $node->[0];
    my $size0 = $subtree_size->{ $dl->[0] };
    if ( $size0 > $pos ) { $i = 0 } else { $i = 1; $pos -= $size0 }
    my $desc = $dl->[$i];

    # Does it go within the subtree, or the branch to the subtree?

    my $len;
    my $added;
    if ( ( $len = $desc->[2] ) <= $pos )
    {
        $added = random_add_to_ultrametric_tree( $desc, $tip, $subtree_size, $pos - $len, $d2tip - $len );
    }
    else
    {
        # If not in subtree, then it goes in the branch to the descendent node
        #
        #     ----- node  ------------       node
        #       ^   /  \       ^             /  \
        #       |       \      | pos             \l1
        #       |        \     v                  \
        #       |      len\ ----------         newnode
        #       |          \                     /  \ l2
        # d2tip |           \                   /    \
        #       |           desc               /     desc
        #       |           /  \            l3/      /  \
        #       |          .    .            /      .    .
        #       v         .      .          /      .      .
        #     -----      .        .     newtip    .        .

        my $l1      = $pos;
        my $l2      = $len   - $pos;
        my $l3      = $d2tip - $pos;
        my $newtip  = [ [], $tip, $l3 ];
        my $newnode = [ [ $desc, $newtip ], undef, $l1 ];
        $dl->[$i]   = $newnode;
        $subtree_size->{ $newtip  } = $l3;
        $subtree_size->{ $newnode } = $subtree_size->{ $desc } + $l3;
        $desc->[2] = $l2;
        $subtree_size->{ $desc } -= $l1;
        $added = $l3;
    }

    #  New branch was inserted below this point:

    $subtree_size->{ $node } += $added;
    return $added;
}



#===============================================================================
#
#  Tree writing and reading
#
#===============================================================================
#
#  writeNewickTree( $tree )
#  writeNewickTree( $tree, $file )
#  writeNewickTree( $tree, \*FH )
#
#-------------------------------------------------------------------------------
sub writeNewickTree
{
    my ( $tree, $file ) = @_;
    my ( $fh, $close ) = open_output( $file );
    $fh or return;
    print  $fh  ( strNewickTree( $tree ), "\n" );
    close $fh if $close;
}


#-------------------------------------------------------------------------------
#  fwriteNewickTree( $file, $tree )     #  Args reversed to writeNewickTree
#-------------------------------------------------------------------------------
sub fwriteNewickTree { writeNewickTree( $_[1], $_[0] ) }


#-------------------------------------------------------------------------------
#  $treestring = strNewickTree( $tree )
#-------------------------------------------------------------------------------
sub strNewickTree
{
    my $node = shift @_;
    strNewickSubtree( $node, "" ) . ";";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $string = strNewickSubtree( $node, $prefix )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub strNewickSubtree
{
    my ( $node, $prefix ) = @_;
    my  $s;

    $s = strNewickComments( newick_c1( $node ), $prefix );
    if ( $s ) { $prefix = " " }

    my $ndesc;
    if ( $ndesc = newick_n_desc( $node ) ) {
        for (my $d = 1; $d <= $ndesc; $d++) {
            $s .= ( ( $d == 1 )  ?  $prefix . "("  :  "," )
               .  strNewickSubtree( newick_desc_i( $node, $d ), " " );
        }

        $s .= ")" . strNewickComments( newick_c2( $node ), " " );
        $prefix = " ";
    }

    if ( node_has_lbl( $node ) ) {
        $s .= $prefix
           .  q_newick_lbl( $node )
           .  strNewickComments( newick_c3( $node ), " " );
    }

    if ( defined( newick_x( $node ) ) ) {
        $s .= ":"
           .   strNewickComments( newick_c4( $node ), " " )
           .   sprintf( " %.6f", newick_x( $node ) )
           .   strNewickComments( newick_c5( $node ), " " );
    }

    $s;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $string = strNewickComments( $clist, $prefix )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub strNewickComments
{
    my ( $clist, $prefix ) = @_;
    array_ref( $clist ) && ( @$clist > 0 ) || return  "";
    $prefix . "[" . join( "] [", @$clist ) . "]";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $quoted_label = q_newick_lbl( $label )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub q_newick_lbl
{
    node_has_lbl( $_[0] ) || return undef;

    my $lbl = newick_lbl( $_[0] );
    if ( $lbl =~ m/^[^][()_:;,]+$/        #  Anything but []()_:;,
      && $lbl !~ m/^'/  ) {               #     and does not start with '
        $lbl =~ s/ /_/g;                  #  Recode blanks as _
        return $lbl;
    }

    else {
        $lbl =~ s/'/''/g;                 #  Double existing single quote marks
        return  q(') . $lbl . q(');       #  Wrap in single quote marks
    }
}


#===============================================================================
#
#  $treestring = formatNewickTree( $tree )
#
#===============================================================================
sub formatNewickTree
{
    formatNewickSubtree( $_[0], "", "" ) . ";";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $string = formatNewickSubtree( $node, $prefix, $indent )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub formatNewickSubtree
{
    my ( $node, $prefix, $indent ) = @_;
    my  $s;

    $s = formatNewickComments( newick_c1( $node ), $prefix, $indent );
    if ( $s ) { $prefix = "\n$indent" }

    if ( my $ndesc = newick_n_desc( $node ) ) {
        for (my $d = 1; $d <= $ndesc; $d++) {
            $s .= ( ( $d == 1 )  ?  $prefix . "("  :  ",\n$indent " )
               .  formatNewickSubtree( newick_desc_i( $node, $d ), " ", $indent . "  " );
        }

        $s .= "\n$indent)" . formatNewickComments( newick_c2( $node ), " ", $indent );
        $prefix = " ";
    }

    if ( node_has_lbl( $node ) ) {
        $s .= $prefix
           .  q_newick_lbl( $node )
           .  formatNewickComments( newick_c3( $node ), " ", $indent );
    }

    if ( defined( newick_x( $node ) ) ) {
        $s .= ":"
           .   formatNewickComments( newick_c4( $node ), " ", $indent )
           .   sprintf(" %.6f", newick_x( $node ) )
           .   formatNewickComments( newick_c5( $node ), " ", $indent );
    }

    $s;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  $string = formatNewickComments( $clist, $prefix, $indent )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub formatNewickComments
{
    my ( $clist, $prefix, $indent ) = @_;
    array_ref( $clist ) && @$clist || return  "";
    $prefix . "[" . join( "] [", @$clist ) . "]";
}


#===============================================================================
#
#  $tree  = read_newick_tree( $file )  # reads to a semicolon
#  @trees = read_newick_trees( $file ) # reads to end of file
#
#===============================================================================

sub read_newick_tree
{
    my $file = shift;
    my ( $fh, $close ) = open_input( $file );
    my $tree;
    my @lines = ();
    foreach ( <$fh> )
    {
        chomp;
        push @lines, $_;
        if ( /;/ )
        {
            $tree = parse_newick_tree_str( join( ' ', @lines ) );
            last;
        }
    }
    close $fh if $close;

    $tree;
}


sub read_newick_trees
{
    my $file = shift;
    my ( $fh, $close ) = open_input( $file );
    my @trees = ();
    my @lines = ();
    foreach ( <$fh> )
    {
        chomp;
        push @lines, $_;
        if ( /;/ )
        {
            push @trees, parse_newick_tree_str( join( ' ', @lines ) );
            @lines = ()
        }
    }
    close $fh if $close;

    @trees;
}


#===============================================================================
#  Tree reader adapted from the C language reader in fastDNAml
#
#  $tree = parse_newick_tree_str( $string )
#
#===============================================================================
sub parse_newick_tree_str
{
    my $s = shift @_;

    my ( $ind, $rootnode ) = parse_newick_subtree( $s, 0 );
    if ( substr( $s, $ind, 1 ) ne ";") { warn "warning: tree missing ';'\n" }
    $rootnode;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Read a subtrees recursively (everything of tree but a semicolon)
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub parse_newick_subtree
{
    my ( $s, $ind ) = @_;

    my $newnode = [];
    my @dlist   = ();
    my ( $lbl, $x, $c1, $c2, $c3, $c4, $c5 );

    ( $ind, $c1 ) = getNextTreeChar( $s, $ind );       #  Comment 1
    if ( ! defined( $ind ) ) { treeParseError( "missing subtree" ) }
    if ( $c1 && @$c1 ) { set_newick_c1( $newnode, $c1 ) }

    if ( substr( $s, $ind, 1 ) eq "(" ) {                #  New internal node
        while ( ! @dlist || ( substr( $s, $ind, 1 ) eq "," ) ) {
            my $desc;
            ( $ind, $desc ) = parse_newick_subtree( $s, $ind+1 );
            if (! $ind) { return () }
            push @dlist, $desc;
        }
        if ( substr( $s, $ind, 1 ) ne ")" ) { treeParseError( "missing ')'" ) }

        ( $ind, $c2 ) = getNextTreeChar( $s, $ind+1 );   #  Comment 2
        if ( $c2 && @$c2 ) { set_newick_c2( $newnode, $c2 ) }
        ( $ind, $lbl ) = parseTreeNodeLabel( $s, $ind ); #  Node label
    }

    elsif ( substr( $s, $ind, 1 ) =~ /[^][(,):;]/ ) {    #  New tip
        ( $ind, $lbl ) = parseTreeNodeLabel( $s, $ind ); #  Tip label
        if (! $ind) { return () }
    }

    @dlist || $lbl || treeParseError( "no descendant list or label" );

    if ( @dlist ) { set_newick_desc_ref( $newnode, \@dlist ) }
    if ( $lbl   ) { set_newick_lbl( $newnode, $lbl ) }

    ( $ind, $c3 ) = getNextTreeChar( $s, $ind );         #  Comment 3
    if ( $c3 && @$c3 ) { set_newick_c3( $newnode, $c3 ) }

    if (substr( $s, $ind, 1 ) eq ":") {                  #  Branch length
        ( $ind, $c4 ) = getNextTreeChar( $s, $ind+1 );   #  Comment 4
        if ( $c4 && @$c4 ) { set_newick_c4( $newnode, $c4 ) }
        ( $ind, $x ) = parseBranchLength( $s, $ind );
        if ( defined( $x ) ) { set_newick_x( $newnode, $x ) }
        ( $ind, $c5 ) = getNextTreeChar( $s, $ind );     #  Comment 5
        if ( $c5 && @$c5 ) { set_newick_c5( $newnode, $c5 ) }
    }

    ( $ind, $newnode );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Read a Newick tree label
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub parseTreeNodeLabel
{  #  Empty string is permitted
    my ( $s, $ind ) = @_;
    my ( $lbl, $c );

    if ( substr( $s, $ind, 1 ) eq "'") {
        my $ind1 = ++$ind;

        while ( ) {
            if ( ! defined( $c = substr( $s, $ind, 1 ) ) || $c eq "" ) {
                treeParseError( "missing close quote on label '" . substr( $s, $ind1 ) . "'" )
            }
            elsif ( $c ne "'"  )                  { $ind++ }
            elsif ( substr( $s, $ind, 2 ) eq "''" ) { $ind += 2 }
            else                                    { last }
        }

        $lbl = substr( $s, $ind1, $ind-$ind1 );
        $lbl =~ s/''/'/g;
        $ind++;
    }

    else {
        my $ind1 = $ind;
        while ( defined( $c = substr($s, $ind, 1) ) && $c ne "" && $c !~ /[][\s(,):;]/ ) { $ind++ }
        $lbl = substr( $s, $ind1, $ind-$ind1 );
        $lbl =~ s/_/ /g;
    }

    ( $ind, $lbl );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Read a Newick tree branch length
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub parseBranchLength
{
    my ( $s, $ind ) = @_;

    my $c = substr( $s, $ind, 1 );

    my $sign = ( $c ne "-" ) ? 1 : -1;      #  Sign
    if ( $c =~ /[-+]/ ) { $c = substr( $s, ++$ind, 1 ) }

    if ( $c !~ /^[.0-9]$/ ) {   #  Allows starting with decimal
        treeParseError( "invalid branch length character '$c'" )
    }

    my $v = 0;
    while ( $c =~ /[0-9]/ ) {               #  Whole number
        $v = 10 * $v + $c;
        $c = substr( $s, ++$ind, 1 );
    }

    if ( $c eq "." ) {                      #  Fraction
        my $f = 0.1;
        $c = substr( $s, ++$ind, 1 );
        while ( $c =~ /[0-9]/ ) {
            $v += $f * $c;
            $f *= 0.1;
            $c  = substr( $s, ++$ind, 1 );
        }
    }

    $v *= $sign;

    if ( $c =~ /[dDeEgG]/ ) {                 #  Exponent
        $c = substr( $s, ++$ind, 1 );
        my $esign = ( $c ne "-" ) ? 1 : -1;
        if ( $c =~ /^[-+]$/ ) { $c = substr( $s, ++$ind, 1 ) }
        if ( $c !~ /^[0-9]$/ ) {
            treeParseError( "missing branch length exponent '$c'" )
        }

        my $e = 0;
        while ( $c =~ /[0-9]/ ) {
            $e = 10 * $e + $c;
            $c = substr( $s, ++$ind, 1 );
        }
        $e *= $esign;
        $v *= 10**$e;
    }

    ( $ind, $v );
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  ( $index, /@commentlist ) = getNextTreeChar( $string, $index )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub getNextTreeChar
{       #  Move to next nonblank, noncomment character
    my ( $s, $ind ) = @_;

    my @clist = ();

    #  Skip white space
    if ( substr( $s, $ind ) =~ /^(\s+)/ ) { $ind += length( $1 ) }

    #  Loop while it is a comment:
    while ( substr( $s, $ind, 1 ) eq "[" ) {
        $ind++;
        my $depth = 1;
        my $ind2  = $ind;

        #  Find end
        while ( $depth > 0 )
        {
            if ( substr( $s, $ind2 ) =~ /^([^][]*\[)/ )     # nested [ ... ]
            {
                $ind2 += length( $1 );  #  Points at char just past [
                $depth++;               #  If nested comments are allowed
            }
            elsif ( substr( $s, $ind2 ) =~ /^([^][]*\])/ )  # close bracket
            {
                $ind2 += length( $1 );  #  Points at char just past ]
                $depth--;
            }
            else
            {
                treeParseError( "comment missing closing bracket '["
                               . substr( $s, $ind ) . "'" )
            }
        }

        my $comment = substr( $s, $ind, $ind2-$ind-1 );
        if ( $comment =~ m/\S/ ) { push @clist, $comment }

        $ind = $ind2;

        #  Skip white space
        if ( substr( $s, $ind ) =~ /^(\s+)/ ) { $ind += length( $1 ) }
    }

    ( $ind, @clist ? \@clist : undef )
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  treeParseError( $message )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub treeParseError { die "Error: parse_newick_subtree: " . $_[0] . "\n" }


#===============================================================================
#  Make a printer plot of a tree:
#
#  printer_plot_newick( $node, $file, $width, $min_dx, $dy )
#  printer_plot_newick( $node, $file, \%options )
#
#     $node   # newick tree root node
#     $file   # undef = \*STDOUT, \*FH, or a file name.
#     $width  # the approximate characters for the tree without labels (D = 68)
#     $min_dx # the minimum horizontal branch length (D = 2)
#     $dy     # the vertical space per taxon (D = 1, most compressed)
#
#  Options:
#
#    dy     => nat_number    # the vertical space per taxon
#    chars  => key           # line drawing character set:
#                            #     html_unicode
#                            #     text (default)
#    min_dx => whole_number  # the minimum horizontal branch length
#    width  => whole_number  # approximate tree width without labels
#
#===============================================================================
sub printer_plot_newick
{
    my ( $node, $file, @opts ) = @_;

    my ( $fh, $close ) = open_output( $file );
    $fh or return;

    my $html = $opts[0] && ref($opts[0]) eq 'HASH'
                        && $opts[0]->{ chars }
                        && $opts[0]->{ chars } =~ /html/;
    print $fh '<PRE>' if $html;
    print $fh join( "\n", text_plot_newick( $node, @opts ) ), "\n";
    print $fh "</PRE>\n" if $html;

    if ( $close ) { close $fh }
}


#===============================================================================
#  Character sets for printer plot trees:
#-------------------------------------------------------------------------------

my %char_set =
  ( text1     => { space  => ' ',
                   horiz  => '-',
                   vert   => '|',
                   el_d_r => '/',
                   el_u_r => '\\',
                   el_d_l => '\\',
                   el_u_l => '/',
                   tee_l  => '+',
                   tee_r  => '+',
                   tee_u  => '+',
                   tee_d  => '+',
                   half_l => '-',
                   half_r => '-',
                   half_u => '|',
                   half_d => '|',
                   cross  => '+',
                 },
    text2     => { space  => ' ',
                   horiz  => '-',
                   vert   => '|',
                   el_d_r => '+',
                   el_u_r => '+',
                   el_d_l => '+',
                   el_u_l => '+',
                   tee_l  => '+',
                   tee_r  => '+',
                   tee_u  => '+',
                   tee_d  => '+',
                   half_l => '-',
                   half_r => '-',
                   half_u => '|',
                   half_d => '|',
                   cross  => '+',
                 },
    html_box  => { space  => '&nbsp;',
                   horiz  => '&#9472;',
                   vert   => '&#9474;',
                   el_d_r => '&#9484;',
                   el_u_r => '&#9492;',
                   el_d_l => '&#9488;',
                   el_u_l => '&#9496;',
                   tee_l  => '&#9508;',
                   tee_r  => '&#9500;',
                   tee_u  => '&#9524;',
                   tee_d  => '&#9516;',
                   half_l => '&#9588;',
                   half_r => '&#9590;',
                   half_u => '&#9589;',
                   half_d => '&#9591;',
                   cross  => '&#9532;',
                 },
    utf8_box  => { space  => ' ',
                   horiz  => chr(226) . chr(148) . chr(128),
                   vert   => chr(226) . chr(148) . chr(130),
                   el_d_r => chr(226) . chr(148) . chr(140),
                   el_u_r => chr(226) . chr(148) . chr(148),
                   el_d_l => chr(226) . chr(148) . chr(144),
                   el_u_l => chr(226) . chr(148) . chr(152),
                   tee_l  => chr(226) . chr(148) . chr(164),
                   tee_r  => chr(226) . chr(148) . chr(156),
                   tee_u  => chr(226) . chr(148) . chr(180),
                   tee_d  => chr(226) . chr(148) . chr(172),
                   half_l => chr(226) . chr(149) . chr(180),
                   half_r => chr(226) . chr(149) . chr(182),
                   half_u => chr(226) . chr(149) . chr(181),
                   half_d => chr(226) . chr(149) . chr(183),
                   cross  => chr(226) . chr(148) . chr(188),
                 },
  );

%{ $char_set{ html1 } } = %{ $char_set{ text1 } };
$char_set{ html1 }->{ space } = '&nbsp;';

%{ $char_set{ html2 } } = %{ $char_set{ text2 } };
$char_set{ html2 }->{ space } = '&nbsp;';

#  Define some synonyms

$char_set{ html } = $char_set{ html_box };
$char_set{ line } = $char_set{ utf8_box };
$char_set{ symb } = $char_set{ utf8_box };
$char_set{ text } = $char_set{ text1 };
$char_set{ utf8 } = $char_set{ utf8_box };

#  Define tree formats and synonyms

my %tree_format =
    ( text         => 'text',
      tree_tab_lbl => 'tree_tab_lbl',
      tree_lbl     => 'tree_lbl',
      chrlist_lbl  => 'chrlist_lbl',
      raw          => 'chrlist_lbl',
    );

#===============================================================================
#  Make a text plot of a tree:
#
#  @lines = text_plot_newick( $node, $width, $min_dx, $dy )
#  @lines = text_plot_newick( $node, \%options )
#
#     $node   # newick tree root node
#     $width  # the approximate characters for the tree without labels (D = 68)
#     $min_dx # the minimum horizontal branch length (D = 2)
#     $dy     # the vertical space per taxon (D = 1, most compressed)
#
#  Options:
#
#    chars  => keyword       # the output character set for the tree
#    dy     => nat_number    # the vertical space per taxon
#    format => keyword       # output format of each line
#    min_dx => whole_number  # the minimum horizontal branch length
#    width  => whole_number  # approximate tree width without labels
#
#  Character sets:
#
#    html       #  synonym of html1
#    html_box   #  html encoding of unicode box drawing characters
#    html1      #  text1 with nonbreaking spaces
#    html2      #  text2 with nonbreaking spaces
#    line       #  synonym of utf8_box
#    raw        #  pass out the internal representation
#    symb       #  synonym of utf8_box
#    text       #  synonym of text1 (Default)
#    text1      #  ascii characters: - + | / \ and space
#    text2      #  ascii characters: - + | + + and space
#    utf8       #  synonym of utf8_box
#    utf8_box   #  utf8 encoding of unicode box drawing characters
#
#  Formats for row lines:
#
#    text           #    $textstring              # Default
#    tree_tab_lbl   #    $treestr \t $labelstr
#    tree_lbl       # [  $treestr,  $labelstr ]
#    chrlist_lbl    # [ \@treechar, $labelstr ]   # Forced with raw chars
#    raw            #  synonym of chrlist_lbl
#
#===============================================================================
sub text_plot_newick
{
    my $node = shift @_;
    array_ref( $node ) || die "Bad node passed to text_plot_newick\n";

    my ( $opts, $width, $min_dx, $dy, $chars, $fmt );
    if ( $_[0] && ref $_[0] eq 'HASH' )
    {
        $opts = shift;
    }
    else
    {
        ( $width, $min_dx, $dy ) = @_;
        $opts = {};
    }

    $chars = $opts->{ chars } || '';
    my $charH;
    $charH = $char_set{ $chars } || $char_set{ 'text1' } if ( $chars ne 'raw' );
    my $is_box = $charH eq $char_set{ html_box }
              || $charH eq $char_set{ utf8_box }
              || $chars eq 'raw';

    $fmt = ( $chars eq 'raw' ) ? 'chrlist_lbl' : $opts->{ format };
    $fmt = $tree_format{ $fmt || '' } || 'text';

    $dy    ||= $opts->{ dy     } ||  1;
    $width ||= $opts->{ width  } || 68;
    $min_dx  = $opts->{ min_dx } if ( ! defined $min_dx || $min_dx < 0 );
    $min_dx  = $is_box ? 1 : 2   if ( ! defined $min_dx || $min_dx < 0 );

    #  Layout the tree:

    $min_dx = int( $min_dx );
    $dy     = int( $dy );
    my $x_scale = $width / ( newick_max_X( $node ) || 1 );  # Div by zero caught by RAE

    my $hash = {};
    layout_printer_plot( $node, $hash, 0, -0.5 * $dy, $x_scale, $min_dx, $dy );

    #  Generate the lines of the tree-one by-one:

    my ( $y1, $y2 ) = @{ $hash->{ $node } };
    my @lines;
    foreach ( ( $y1 .. $y2 ) )
    {
        my $line = text_tree_row( $node, $hash, $_, [], 'tee_l', $dy >= 2 );
        my $lbl  = '';
        if ( @$line )
        {
            if ( $line->[-1] eq '' ) { pop @$line; $lbl = pop @$line }
            #  Translate tree characters
            @$line = map { $charH->{ $_ } } @$line if $chars ne 'raw';
        }

        # Convert to requested output format:

        push @lines, $fmt eq 'text'         ? join( '', @$line, ( $lbl ? " $lbl" : () ) )
                   : $fmt eq 'text_tab_lbl' ? join( '', @$line, "\t", $lbl )
                   : $fmt eq 'tree_lbl'     ? [ join( '', @$line ), $lbl ]
                   : $fmt eq 'chrlist_lbl'  ? [ $line, $lbl ]
                   :                          ();
    }

    # if ( $cells )
    # {
    #     my $nmax = 0;
    #     foreach ( @lines ) { $nmax = @$_ if @$_ > $nmax }
    #     foreach ( @lines )
    #     {
    #         @$_ = map { "<TD>$_</TD>" } @$_;
    #         my $span = $nmax - @$_ + 1;
    #         $_->[-1] =~ s/^<TD>/<TD NoWrap ColSpan=$span>/;
    #     }
    # }
    # elsif ( $tables )
    # {
    #     my $nmax = 0;
    #     foreach ( @lines ) { $nmax = @$_ if @$_ > $nmax }
    #     foreach ( @lines )
    #     {
    #         @$_ = map { "<TD>$_</TD>" } @$_;
    #         my $span = $nmax - @$_ + 1;
    #         $_->[-1] =~ s/^<TD>/<TD NoWrap ColSpan=$span>/;
    #     }
    # }

    wantarray ? @lines : \@lines;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  ( $xmax, $ymax, $root_y ) = layout_printer_plot( $node, $hash, $x0, $y0, $x_scale, $min_dx, $dy, $yrnd )
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub layout_printer_plot
{
    my ( $node, $hash, $x0, $y0, $x_scale, $min_dx, $dy, $yrnd ) = @_;
    array_ref( $node ) || die "Bad node ref passed to layout_printer_plot\n";
    hash_ref(  $hash ) || die "Bad hash ref passed to layout_printer_plot\n";

    my $dx = newick_x( $node );
    if ( defined( $dx ) ) {
        $dx *= $x_scale;
        $dx = $min_dx if $dx < $min_dx;
    }
    else {
        $dx = ( $x0 > 0 ) ? $min_dx : 0;
    }
    $dx = int( $dx + 0.4999 );

    my ( $x, $xmax, $y, $ymax, $y1, $y2, $yn1, $yn2 );

    $x = $x0 + $dx;
    $y1 = int( $y0 + 0.5 * $dy + 0.4999 );
    my @dl = newick_desc_list( $node );

    if ( ! @dl ) {               #  A tip
        $xmax  = $x;
        $y = $yn1 = $yn2 = $y2 = $y1;
        $ymax  = $y + 0.5 * $dy;
    }

    else {                       #  A subtree
        $xmax = -1;
        my $xmaxi;
        my $yi;
        my @ylist = ();
        $ymax = $y0;

        foreach ( @dl ) {
            ( $xmaxi, $ymax, $yi ) = layout_printer_plot( $_, $hash, $x, $ymax, $x_scale, $min_dx, $dy,
                                                          ( 2*@ylist < @dl ? 0.5001 : 0.4999 )
                                                        );
            push @ylist, $yi;
            if ( $xmaxi > $xmax ) { $xmax = $xmaxi }
        }

        #  Use of y-list is overkill for saving first and last values,
        #  but eases implimentation of alternative y-value calculations.

        $yn1 = $ylist[ 0];
        $yn2 = $ylist[-1];
        $y   = int( 0.5 * ( $yn1 + $yn2 ) + ( $yrnd || 0.4999 ) );

        #  Handle special case of internal node label. Put it between subtrees.

        if ( ( $dy >= 2 ) && node_has_lbl( $node ) && ( @dl > 1 ) ) {
            #  Find the descendents $i1 and $i2 to put the branch between
            my $i2 = 1;
            while ( ( $i2+1 < @ylist ) && ( $ylist[$i2] < $y ) ) { $i2++ }
            my $i1 = $i2 - 1;
            #  Get bottom of subtree1 and top of subtree2:
            my $ymax1 = $hash->{ $dl[ $i1 ] }->[ 1 ];
            my $ymin2 = $hash->{ $dl[ $i2 ] }->[ 0 ];
            #  Midway between bottom of subtree1 and top of subtree2, with
            #  preferred rounding direction
            $y = int( 0.5 * ( $ymax1 + $ymin2 ) + ( $yrnd || 0.4999 ) );
        }
    }

    $y2 = int( $ymax - 0.5 * $dy + 0.4999 );

    $hash->{ $node } = [ $y1, $y2, $x0, $x, $y, $yn1, $yn2 ];
    ( $xmax, $ymax, $y );
}


#  What symbol do we get if we add a leftward line to some other symbol?

my %with_left_line = ( space  => 'half_l',
                       horiz  => 'horiz',
                       vert   => 'tee_l',
                       el_d_r => 'tee_d',
                       el_u_r => 'tee_u',
                       el_d_l => 'el_d_l',
                       el_u_l => 'el_u_l',
                       tee_l  => 'tee_l',
                       tee_r  => 'cross',
                       tee_u  => 'tee_u',
                       tee_d  => 'tee_d',
                       half_l => 'half_l',
                       half_r => 'horiz',
                       half_u => 'el_u_l',
                       half_d => 'el_d_l',
                       cross  => 'cross',
                     );

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Produce a description of one line of a printer plot tree.
#
#  \@line = text_tree_row( $node, $hash, $row, \@line, $symb, $ilbl )
#
#     \@line is the character descriptions accumulated so far, one per array
#          element, except for a label, which can be any number of characters.
#          Labels are followed by an empty string, so if $line->[-1] eq '',
#          then $line->[-2] is a label. The calling program translates the
#          symbol names to output characters.
#
#     \@node is a newick tree node
#     \%hash contains tree layout information
#      $row  is the row number (y value) that we are building
#      $symb is the plot symbol proposed for the current x and y position
#      $ilbl is true if internal node labels are allowed
#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub text_tree_row
{
    my ( $node, $hash, $row, $line, $symb, $ilbl ) = @_;

    my ( $y1, $y2, $x0, $x, $y, $yn1, $yn2 ) = @{ $hash->{ $node } };
    if ( $row < $y1 || $row > $y2 ) { return $line }

    if ( @$line < $x0 ) { push @$line, ('space') x ( $x0 - @$line ) }

    if ( $row == $y ) {
        while ( @$line > $x0 ) { pop @$line }  # Actually 0-1 times
        push @$line, $symb,
                     ( ( $x > $x0 ) ? ('horiz') x ($x - $x0) : () );
    }

    elsif ( $row > $yn1 && $row < $yn2 ) {
        if ( @$line < $x ) { push @$line, ('space') x ( $x - @$line ), 'vert' }
        else               { $line->[$x] = 'vert' }
    }

    my @dl = newick_desc_list( $node );

    if ( @dl < 1 ) {
        push @$line, ( node_has_lbl( $node ) ? newick_lbl( $node ) : '' ), '';
    }

    else {
        my @list = map { [ $_, 'tee_r' ] } @dl;  # Line to the right
        if ( @list > 1 ) { #  Fix top and bottom sympbols
            $list[ 0]->[1] = 'el_d_r';
            $list[-1]->[1] = 'el_u_r';
        }
        elsif ( @list ) {  # Only one descendent
            $list[ 0]->[1] = 'half_r';
        }
        foreach ( @list ) {
            my ( $n, $s ) = @$_;
            if ( $row >= $hash->{ $n }->[0] && $row <= $hash->{ $n }->[1] ) {
                $line = text_tree_row( $n, $hash, $row, $line, $s, $ilbl );
            }
        }

        if ( $row == $y ) {
            $line->[$x] = ( $line->[$x] eq 'horiz' ) ? 'tee_l'
                                                     : $with_left_line{ $line->[$x] };
            push @$line, newick_lbl( $node), '' if $ilbl && node_has_lbl( $node );
        }
    }

    return $line;
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Debug routine
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub dump_tree
{
    my ( $node, $prefix ) = @_;
    defined( $prefix ) or $prefix = "";
    print STDERR $prefix, join(", ", @$node), "\n";
    my @dl = $node->[0] ? @{$node->[0]} : ();
    foreach ( @dl ) { dump_tree( $_, $prefix . "  " ) }
    $prefix or print STDERR "\n";
}


#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Debug routine
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub dump_tree_hash
{
    my ( $node, $hash, $prefix ) = @_;
    defined( $prefix ) or print STDERR "node; [ y1, y2, x0, x, y, yn1, yn2 ]\n" and $prefix = "";
    print STDERR $prefix, join(", ", @$node), "; ", join(", ", @{ $hash->{ $node } } ), "\n";
    my @dl = $node->[0] ? @{$node->[0]} : ();
    foreach (@dl) { dump_tree_hash( $_, $hash, $prefix . "  " ) }
}


#===============================================================================
#  Open an input file stream:
#
#     ( $handle, undef ) = open_input(       );  # \*STDIN
#     ( $handle, undef ) = open_input( \*FH  );
#     ( $handle, 1     ) = open_input( $file );  # need to close $handle
#
#===============================================================================
sub open_input
{
    my $file = shift;
    my $fh;
    if    ( ! defined $file || $file eq '' ) { return ( \*STDIN ) }
    elsif ( ref( $file ) eq 'GLOB' )         { return ( $file   ) }
    elsif ( open( $fh, "<$file" ) )          { return ( $fh, 1  ) } # Need to close

    print STDERR "gjonewick::open_input could not open '$file' for reading\n";
    return undef;
}


#===============================================================================
#  Open an output file stream:
#
#     ( $handle, undef ) = open_output(      );  # \*STDOUT
#     ( $handle, undef ) = open_output( \*FH );
#     ( $handle, 1     ) = open_output( $file ); # need to close $handle
#
#===============================================================================
sub open_output
{
    my $file = shift;
    my $fh;
    if    ( ! defined $file || $file eq '' ) { return ( \*STDOUT ) }
    elsif ( ref( $file ) eq 'GLOB' )         { return ( $file    ) }
    elsif ( ( open $fh, ">$file" ) )         { return ( $fh, 1   ) } # Need to close

    print STDERR "gjonewick::open_output could not open '$file' for writing\n";
    return undef;
}


#===============================================================================
#  Some subroutines copied from gjolists
#===============================================================================
#  Return the common prefix of two lists:
#
#  @common = common_prefix( \@list1, \@list2 )
#
#-----------------------------------------------------------------------------
sub common_prefix
{
    my ($l1, $l2) = @_;
    ref($l1) eq "ARRAY" || die "common_prefix: arg 1 is not an array ref\n";
    ref($l2) eq "ARRAY" || die "common_prefix: arg 2 is not an array ref\n";

    my $i = 0;
    my $l1_i;
    while ( defined( $l1_i = $l1->[$i] ) && $l1_i eq $l2->[$i] ) { $i++ }

    return @$l1[ 0 .. ($i-1) ];  # perl handles negative range
}


#-----------------------------------------------------------------------------
#  Return the unique suffixes of each of two lists:
#
#  ( \@suffix1, \@suffix2 ) = unique_suffixes( \@list1, \@list2 )
#
#-----------------------------------------------------------------------------
sub unique_suffixes
{
    my ($l1, $l2) = @_;
    ref($l1) eq "ARRAY" || die "common_prefix: arg 1 is not an array ref\n";
    ref($l2) eq "ARRAY" || die "common_prefix: arg 2 is not an array ref\n";

    my $i = 0;
    my @l1 = @$l1;
    my @l2 = @$l2;
    my $l1_i;
    while ( defined( $l1_i = $l1[$i] ) && $l1_i eq $l2[$i] ) { $i++ }

    splice @l1, 0, $i;
    splice @l2, 0, $i;
    return ( \@l1, \@l2 );
}


#-------------------------------------------------------------------------------
#  List of values duplicated in a list (stable in order by second occurance):
#
#  @dups = duplicates( @list )
#
#-------------------------------------------------------------------------------
sub duplicates
{
    my %cnt = ();
    grep { ++$cnt{$_} == 2 } @_;
}


#-------------------------------------------------------------------------------
#  Randomize the order of a list:
#
#  @random = random_order( @list )
#
#-------------------------------------------------------------------------------
sub random_order
{
    my ( $i, $j );
    for ( $i = @_ - 1; $i > 0; $i-- )
    {
        $j = int( ($i+1) * rand() );
        ( $_[$i], $_[$j] ) = ( $_[$j], $_[$i] ); # Interchange i and j
    }

   @_;
}


#-----------------------------------------------------------------------------
#  Intersection of two or more sets:
#
#  @intersection = intersection( \@set1, \@set2, ... )
#
#-----------------------------------------------------------------------------
sub intersection
{
    my $set = shift;
    my @intersection = @$set;

    foreach $set ( @_ )
    {
        my %set = map { $_ => 1 } @$set;
        @intersection = grep { exists $set{ $_ } } @intersection;
    }

    @intersection;
}


#-----------------------------------------------------------------------------
#  Elements in set 1, but not set 2:
#
#  @difference = set_difference( \@set1, \@set2 )
#
#-----------------------------------------------------------------------------
sub set_difference
{
    my ($set1, $set2) = @_;
    my %set2 = map { $_ => 1 } @$set2;
    grep { ! ( exists $set2{$_} ) } @$set1;
}


1;
