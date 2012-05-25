########################################################################
# ModelSEED::Database::Iterator::MongoDB - Iterator wrapper 
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2012-05-21
########################################################################
package ModelSEED::Database::Iterator::MongoDB;
use Moose;
use MongoDB::Cursor;
with 'ModelSEED::Database::Iterator';

has _cursor => (
    is       => 'ro',
    isa      => 'MongoDB::Cursor',
    required => 1
);

sub next {
    return $_[0]->_cursor->next;
}

sub all {
    return $_[0]->_cursor->all;
}

sub count {
    return $_[0]->_cursor->count(1);
}

1;
