########################################################################
# ModelSEED::Database::Iterator - Abstract role / interface iterators
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-21
########################################################################
=pod

=head1 ModelSEED::Database::Iterator

Abstract role / interface for iterators

=head1 Methods

=head2 next

    while ( my $object = $itr->next ) {
        ...
    }

Return the next entry in the iterator. When the iterator is exhausted,
return undef.

=head2 all

    my @objects = $itr->all

Return an array of all the objects in the result.

=cut
package ModelSEED::Database::Iterator;
use Moose::Role;

requires 'next';
requires 'all';
requires 'count';

1;
