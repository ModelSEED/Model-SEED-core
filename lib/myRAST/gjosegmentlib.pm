# gjosegmentlib.pm
#
#   A library of functions for finding the interval in which a coordinate falls.
#   Intervals are placed end to end.  Each has an id and a length.
#

#
# This is a SAS Component
#

#  Usage:
#
#  use gjosegmentlib
#
#   $tree = $rootnode
#   $node = [ $id, $seglen, $lref, $rref, $h, $llen, $mlen, $tlen ]
#
#             $id     an arbitrary id, which can be a reference to arbitrary data
#                          (the tree is in $id order)
#             $seglen the length of the segment represented by the node (>= 0)
#             $lref   reference to left descendent or undef
#             $rref   reference to right descendent or undef
#             $h      height of node, for balancing
#             $llen   start point of length interval (length of left subtree)
#             $mlen   endpoint of length interval (= $llen + $seglen)
#             $tlen   total node length (= $mlen + length of right subtree)
#
#  Whole tree functions:
#
#  $tree    = segment_new_tree( @pairs )            # make a tree with [ id, length ] pairs
#  $n       = segment_count( $tree )                # number of nodes in the tree
#  $length  = segment_total( $tree )                # total length of segments in tree
#  @pairs   = segment_flatten( $tree )              # return all [ id, length ] pairs
#
#  segment_debug( $node )
#  segment_print( $tree )                           # print ordered id and length pairs
#
#  Tree element functions:
#
#  $length  = segment_length( $id, $tree )          # return length at segment node with given id
#  $node    = segment_raw_search( $id, $tree)       # return reference to segment node with given id
#  $id      = segment_next_id( $query, $tree )      # first id > query
#  $id      = segment_prev_id( $query, $tree )      # first id < query
#  $tree    = segment_add( $id, $length, $tree )    # insert new id and length into segment tree
#  $tree    = segment_del( $id, $tree )             # delete an id and length from segment tree
#
#  Coordinate-based functions:
#
#  $id            = segment_by_coord( $coord, $tree )
#  ( $tree, $id ) = segment_del_by_coord( $coord, $tree )
#  ( $tree, $id ) = segment_del_random( $tree )
#
#  Node information functions:
#
#  $id      = segment_id( $node ) 
#  $seglen  = segment_len( $node ) 
#  $lref    = segment_l( $node ) 
#  $rref    = segment_r( $node ) 
#  $h       = segment_h( $node ) 
#  $llen    = segment_llen( $node ) 
#  $mlen    = segment_mlen( $node ) 
#  $tlen    = segment_tlen( $node ) 
#

package gjosegmentlib;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
        segment_new_tree
        segment_count
        segment_total
        segment_flatten
        segment_print
        segment_debug
        segment_length
        segment_next_id
        segment_prev_id
        segment_add
        segment_del
        segment_by_coord
        segment_del_by_coord
        segment_del_random
        );

our @EXPORT_OK = qw(
        segment_raw_search
        segment_balance
        segment_join
        segment_r_tip
        segment_l_tip
        segment_id
        segment_len
        segment_l
        segment_r
        segment_h
        segment_llen
        segment_mlen
        segment_tlen
        set_id
        set_len
        set_l
        set_r
        set_h
        set_llen
        set_mlen
        set_tlen
        segment_new_tip
        segment_update_h
        );

#-----------------------------------------------------------------------------
#  Count nodes in segment tree
#-----------------------------------------------------------------------------

sub segment_count
{
    my ( $node ) = @_;
    is_node( $node ) ? 1 + segment_count( segment_l( $node ) )
                         + segment_count( segment_r( $node ) )
                     : 0
}


#-----------------------------------------------------------------------------
#  Total length of segments
#-----------------------------------------------------------------------------

sub segment_total
{
    my ( $node ) = @_;
    is_node( $node ) ? segment_tlen( $node ) : undef
}


#-----------------------------------------------------------------------------
#  Return ordered id and length pairs from segment tree
#-----------------------------------------------------------------------------

sub segment_flatten
{
    my ( $node ) = @_;
    is_node( $node ) ? ( segment_flatten( segment_l( $node ) ),
                         [ segment_id( $node ), segment_len( $node ) ],
                         segment_flatten( segment_r( $node ) )
                       )
                     : ()
}


#-----------------------------------------------------------------------------
#  Print the id value pair in the tree
#-----------------------------------------------------------------------------

sub segment_print
{
    print  join( "\n", map { "$_->[0] => $_->[1]" }
                       segment_flatten( @_ )
               ), "\n"
}


#-----------------------------------------------------------------------------
#  Print the tree nodes in order
#-----------------------------------------------------------------------------

sub segment_debug
{
    my ( $node ) = @_;
    is_node( $node ) || return;

    segment_debug( segment_l( $node ) );
    print STDERR join( "\t", $node, @$node ), "\n";
    segment_debug( segment_r( $node ) );
}


#-----------------------------------------------------------------------------
#  Return length at segment node with given id, or null if not found
#-----------------------------------------------------------------------------

sub segment_length
{
    my ( $id, $tree ) = @_;
    return  segment_len( segment_raw_search( $id, $tree ) );
}


#-----------------------------------------------------------------------------
#  Return index of segment node with given id, or null if not found
#-----------------------------------------------------------------------------

sub segment_raw_search
{
    my ( $id, $node ) = @_;
    is_node( $node ) || return  undef;

    my $dir = $id cmp segment_id( $node );

    $dir < 0 ? segment_raw_search( $id, segment_l( $node ) ) :
    $dir > 0 ? segment_raw_search( $id, segment_r( $node ) ) :
               $node;
}


#-----------------------------------------------------------------------------
#  Return the next id > id in a segment tree, or undef if there is none
#
#  $nextid = segment_next_id( $id, $tree )
#-----------------------------------------------------------------------------

sub segment_next_id
{
    my ($id, $node, $nextid) = @_;
    is_node( $node ) || return $nextid;

    my $nodeid = segment_id( $node );
    my $dir    = $id cmp $nodeid;
    $dir < 0 ? segment_next_id( $id, segment_l( $node ), $nodeid )
             : segment_next_id( $id, segment_r( $node ), $nextid );
}


#-----------------------------------------------------------------------------
#  Return the prev id < id in a segment tree, or undef if there is none
#
#  $prev_id = segment_prev_id( $id, $tree )
#-----------------------------------------------------------------------------

sub segment_prev_id
{
    my ($id, $node, $previd) = @_;
    is_node( $node ) || return  $previd;

    my $nodeid = segment_id( $node );
    my $dir    = $id cmp $nodeid;
    $dir > 0 ? segment_prev_id( $id, segment_r( $node ), $nodeid )
             : segment_prev_id( $id, segment_l( $node ), $previd );
}


#-----------------------------------------------------------------------------
#  Insert new id and length into segment tree, returning tree (and status)
#
#  ( $tree, $added ) = segment_add( $id, $length, $tree )
#    $tree           = segment_add( $id, $length, $tree )
#-----------------------------------------------------------------------------

sub segment_add
{
    my ( $id, $length, $node ) = @_;
    my $added = 0;

    if ( is_node( $node ) )
    {
        my $dir = $id cmp $node;
    
        if ( $dir < 0 )
        {
            my $nl = segment_l( $node );
 
            if ( ! $nl )
            {
                set_l( $node, segment_new_tip( $id, $length ) );
                segment_update_h( $node );
                $added = 1;
            }
            else
            {
                my $n2;
                ( $n2, $added ) = segment_add( $id, $length, $nl );
                $node = segment_balance( $n2, segment_r( $n2 ), $node );
            }
        }

        elsif ( $dir > 0 )
        {
            my $nr = segment_r( $node );
            if ( ! $nr )
            {
                set_r( $node, segment_new_tip( $id, $length ) );
                segment_update_h( $node );
                $added = 1;
            }
            else
            {
                my $n4;
                ( $n4, $added ) = segment_add( $id, $length, $nr );
                $node = segment_balance( $node, segment_l( $n4 ), $n4 );
            }
        }

        #  If already exists, silently do nothing
    }

    else  #  This is adding to an empty tree
    {
        $node = segment_new_tip( $id, $length );
        $added = 1;
    }

    wantarray ? ( $node, $added ) : $node;
}


#-----------------------------------------------------------------------------
# delete an id and length from segment tree, returning pointer to tree
#
#  ( $tree, $found ) = segment_del( $id, $tree )
#-----------------------------------------------------------------------------

sub segment_del
{
    my ( $id, $node ) = @_;
    my $found = 0;

    if ( is_node( $node ) )
    {
        my $dir = $id cmp segment_id( $node );

        if ( $dir < 0 )
        {
            my $nl;
            ( $nl, $found ) = segment_del( $id, segment_l( $node ) );
            if ( $found )
            {
                set_l( $node, $nl );
                my $n4 = segment_r( $node );
                $node = segment_balance( $node, segment_l( $n4 ), $n4 );
            }
        }

        elsif ( $dir > 0 )
        {
            my $nr;
            ( $nr, $found ) = segment_del( $id, segment_r( $node ) );
            if ( $found )
            {
                set_r( $node, $nr );
                my $n2 = segment_l($node);
                $node = segment_balance( $n2, segment_r( $n2 ), $node );
            }
        }

        else {                                                  #  Found it
            $node = segment_join( segment_l( $node ), segment_r( $node ) );
            $found = 1;
        }
    }

    wantarray ? ( $node, $found ) : $node;
}


#-----------------------------------------------------------------------------
#  Coordinate-based functions:
#
#  $id            = segment_by_coord( $coord, $tree )
#  ( $tree, $id ) = segment_del_by_coord( $coord, $tree )
#  ( $tree, $id ) = segment_del_random( $tree )
#-----------------------------------------------------------------------------

sub segment_by_coord
{
    my ( $coord, $node ) = @_;
    is_node( $node ) and ( $coord >= 0 ) and ( $coord <= segment_tlen( $node ) ) or return undef;

    if ( segment_llen( $node ) > $coord )
    {
        my $l = segment_l( $node );
        return $l ? segment_by_coord( $coord, $l ) : segment_id( $node );
    }
    my $ml = segment_mlen( $node );

    if ( $ml < $coord )
    {
        my $r = segment_r( $node );
        return $r ? segment_by_coord( $coord-$ml, $r ) : segment_id( $node );
    }

    segment_id( $node )
}


sub segment_del_by_coord
{
    my ( $coord, $tree ) = @_;
    my $id = segment_by_coord( $coord, $tree );
    $id ? ( ( segment_del( $id, $tree ) )[0], $id ) : ( $tree, undef )
}


sub segment_del_random
{
    my ( $tree ) = @_;
    return undef if ! is_node( $tree );

    my $id = segment_by_coord( rand() * segment_tlen( $tree ), $tree );
    $id ? ( ( segment_del( $id, $tree ) )[0], $id ) : ( $tree, undef )
}


#-----------------------------------------------------------------------------
#
#                      n2    n4
#                     /  .  .  \
#                   n1    n3    n5
#                        /  \
#                      n3l  n3r
#
#                            $h1 >= $h3       $h5 >= $h3
#   ! $n2        ! $n4       $h1 >= $h5       $h5 >= $h1         otherwise
#  --------     --------     -----------      -----------      --------------
#     n4           n2           n2                  n4               n3
#    /  \         /  \         /  \                /  \             /  \
#  n3    n5     n1    n3     n1    n4            n2    n5         n2    n4
#                                 /  \          /  \             / \    / \
#                               n3    n5      n1    n3         n1 n3l  n3r n5
#
#-----------------------------------------------------------------------------
# root segment subtrees to maintain balance
#-----------------------------------------------------------------------------

sub segment_balance
{
    my ( $n2, $n3, $n4 ) = @_;

    if ( ! is_node( $n2 ) )
    {
        if ( ! is_node( $n4 ) ) { return $n3 }
        set_l( $n4, $n3 );
        segment_update_h( $n4 );
        return $n4;
    }

    if ( ! is_node( $n4 ) )
    {
        set_r( $n2, $n3 );
        segment_update_h( $n2 );
        return $n2;
    }

    my ($n1, $n3l, $n3r, $n5, $h1, $h3, $h5);
    $n1 = segment_l( $n2 );
    $h1 = segment_h( $n1 );
    $h3 = segment_h( $n3 );
    $n5 = segment_r( $n4 );        
    $h5 = segment_h( $n5 );

    if ( $h1 >= $h3 && $h1 >= $h5 )
    {
        set_r( $n2, $n4 );
        set_l( $n4, $n3 );
        segment_update_h( $n4 );
        segment_update_h( $n2 );
        return $n2;
    }

    if ($h5 >= $h3 && $h5 >= $h1)
    {
        set_r( $n2, $n3 );
        set_l( $n4, $n2 );
        segment_update_h( $n2 );
        segment_update_h( $n4 );
        return $n4;
    }

    else
    {
        $n3l = segment_l( $n3 );
        $n3r = segment_r( $n3 );
        set_r( $n2, $n3l );
        set_l( $n3, $n2 );
        set_r( $n3, $n4 );
        set_l( $n4, $n3r );
        segment_update_h( $n2 );
        segment_update_h( $n4 );
        segment_update_h( $n3 );
        return $n3;
    }
}


#-----------------------------------------------------------------------------
#
#                     /  \
#                   nl    nr
#
#-----------------------------------------------------------------------------
#  Join 2 segment subtrees for which common parent has been deleted
#-----------------------------------------------------------------------------

sub segment_join
{
    my ($nl, $nr) = @_;

    is_node( $nl ) || return $nr;      # Correctly handles n3 = undef
    is_node( $nr ) || return $nl;

    ( segment_h( $nl ) >= segment_h( $nr ) ) 
        ? segment_balance( segment_r_tip( $nl, undef ), segment_l( $nr ), $nr )
        : segment_balance( $nl, segment_r( $nl ), segment_l_tip( $nr, undef ) );
}


#-----------------------------------------------------------------------------
#  Remove rightmost tip from segment tree and return it to the top
#-----------------------------------------------------------------------------

sub segment_r_tip
{
    my ($node, $parent) = @_;
    $node || return undef;

    my ($rtip, $nl, $nr, $n3, $new);
    $nr = segment_r( $node );
    if (! $nr ) {                   # This is "tip"
        if ( $parent )
        {
            set_r( $parent, segment_l( $node ) );
            set_l( $node, undef);
        }
        return $node;
    }

    $rtip = segment_r_tip( $nr, $node );   # Continue descent into right subtree
    $rtip || die "segment_r_tip: bad tree\n";

    $nl  = segment_l( $node );
    $n3  = segment_r( $nl );
    $new = segment_balance( $nl, $n3, $node );

    if    ( ! $parent     ) { set_l( $rtip,   $new ) }
    elsif ( $new ne $node ) { set_r( $parent, $new ) }

    $rtip;
  }


#-----------------------------------------------------------------------------
#  Remove leftmost tip from segment tree and return it to the top
#-----------------------------------------------------------------------------

sub segment_l_tip
{
    my ($node, $parent) = @_;
    $node || return undef;

    my ($ltip, $nl, $nr, $n3, $new);
    $nl = segment_l( $node );
    if ( ! $nl ) {               # This is "tip"
        if ( $parent )
        {
              set_l( $parent, segment_r( $node ) );
              set_r( $node, undef);
        }
        return $node;
    }

    $ltip = segment_l_tip( $nl, $node );   # Continue descent into left subtree
    $ltip || die "segment_l_tip: bad tree\n";

    $nr  = segment_r( $node );
    $n3  = segment_l( $nr );
    $new = segment_balance( $node, $n3, $nr );

    if    ( ! $parent    ) { set_r( $ltip,   $new ) }
    elsif ( $new ne $node) { set_l( $parent, $new ) }

    $ltip;
  }


#-----------------------------------------------------------------------------
#  Update the height and coordinate data for a node after an edit of the tree
#-----------------------------------------------------------------------------

sub segment_update_h
{
    my ($n) = @_;
    ref( $n) eq "ARRAY" || return undef;

    my $nl = segment_l( $n );
    my ( $hl, $ll ) = $nl ? ( segment_h( $nl ), segment_tlen( $nl ) ) : ( 0, 0 );
    my $nr = segment_r( $n );
    my ( $hr, $lr ) = $nr ? ( segment_h( $nr ), segment_tlen( $nr ) ) : ( 0, 0 );
    my $mlen = $ll + segment_len( $n );

    set_h(    $n, max( $hl, $hr ) + 1 );
    set_llen( $n, $ll );
    set_mlen( $n, $mlen );
    set_tlen( $n, $mlen + $lr )
}


#-----------------------------------------------------------------------------
#  Is the arguement a valid node?
#-----------------------------------------------------------------------------

sub is_node
{
    my ( $n ) = @_;
    ref( $n ) eq "ARRAY" && defined( $n->[0] ) && defined( $n->[4] )
}


#-----------------------------------------------------------------------------
#  Extract id, length, lnode, rnode, height, llen, mlen or tlen
#
#   $node = [ $id, $seglen, $lref, $rref, $h, $llen, $mlen, $tlen ]
#-----------------------------------------------------------------------------

sub segment_id   { ref( $_[0] ) eq "ARRAY" ? $_[0]->[0] : undef }
sub segment_len  { ref( $_[0] ) eq "ARRAY" ? $_[0]->[1] : undef }
sub segment_l    { ref( $_[0] ) eq "ARRAY" ? $_[0]->[2] : undef }
sub segment_r    { ref( $_[0] ) eq "ARRAY" ? $_[0]->[3] : undef }
sub segment_h    { ref( $_[0] ) eq "ARRAY" ? $_[0]->[4] : 0 }
sub segment_llen { ref( $_[0] ) eq "ARRAY" ? $_[0]->[5] : 0 }
sub segment_mlen { ref( $_[0] ) eq "ARRAY" ? $_[0]->[6] : 0 }
sub segment_tlen { ref( $_[0] ) eq "ARRAY" ? $_[0]->[7] : 0 }


#-----------------------------------------------------------------------------
#  Set id, length, lnode, rnode, height, llen, mlen or tlen
#  Return the value assigned.
#-----------------------------------------------------------------------------

sub set_id   { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[0] = $_[1] ) : undef }
sub set_len  { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[1] = $_[1] ) : undef }
sub set_l    { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[2] = $_[1] ) : undef }
sub set_r    { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[3] = $_[1] ) : undef }
sub set_h    { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[4] = $_[1] ) : undef }
sub set_llen { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[5] = $_[1] ) : undef }
sub set_mlen { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[6] = $_[1] ) : undef }
sub set_tlen { ref( $_[0] ) eq "ARRAY" ? ( $_[0]->[7] = $_[1] ) : undef }


#-----------------------------------------------------------------------------
#  Make a new segment tree from list of [ id, length ] pairs
#-----------------------------------------------------------------------------

sub segment_new_tree { ( quick_tree( sort { $a->[0] cmp $b->[0] } @_ ) )[0] }


#-----------------------------------------------------------------------------
#  Make a new segment tree from sorted list of [ id, length ] pairs
#
#  ( $tree, $height, $length ) = quick_tree( @pairs );
#-----------------------------------------------------------------------------

sub quick_tree
{
    @_ or return ( undef, 0, 0 );
    @_ == 1 and return ( segment_new_tip( @{ $_[0] } ), 1, $_[0]->[1] );

    my ( $l, $hl, $ll ) = quick_tree( splice @_, 0, int( @_ / 2 ) );
    my $n = segment_new_tip( @{ shift @_ } );
    my ( $r, $hr, $lr ) = quick_tree( @_ );
    my $h = max( $hl, $hr ) + 1;
    my $mlen = $ll + segment_len( $n );
    my $tlen = $mlen + $lr;

    splice @$n, 2, 6, ( $l, $r, $h, $ll, $mlen, $tlen );
    ( $n, $h, $tlen )
}

sub max { $_[0] >= $_[1] ? $_[0] : $_[1] }


#-----------------------------------------------------------------------------
#  Make a new tip node
#-----------------------------------------------------------------------------

sub segment_new_tip
{
    my ( $id, $length ) = @_;
    defined( $id ) && $length >= 0 or return undef;
    [ $id, $length, undef, undef, 1, 0, $length, $length ]
}


1;

