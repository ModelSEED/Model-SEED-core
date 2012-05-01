########################################################################
# ModelSEED::Database - Abstract role / interface for Database drivers
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development locations: 
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#                       
# Date of module creation: 2012-04-01
########################################################################
=pod

=head1 ModelSEED::Database

An abstract role / interface for database drivers.

=head1 Methods

=head2 has_object

    $bool = $db->has_object(type, id);

=head2 get_object

    $obj  = $db->get_object(type, id);

=head2 save_object

    $bool = $db->save_object(type, id, object);

Object can be hash/array ref or an already encoded JSON string


=head2 delete_object

    $count = $db->delete_object(type, id);

=head2 get_metadata

    $meta = $db->get_metadata(type, id, selection);

Selection can be specified to return specific meta-data and uses dot
notation to select inside sub-objects

    meta: {name => 'foo', users => {paul => 'bar', zedd => 'test'}}

    $db->get_metadata('type', '0123', 'users.paul');
    returns: 'bar'

    $db->get_metadata('type', '0123', 'users');
    returns: { paul => 'bar', zedd => 'test' }

=head2 set_metadata

    $bool = $db->set_metadata(type, id, selection, metadata);

Selection specifies where to save metadata (uses dot notation) if
selection is C<undef> or the empty string, will set the whole metadata
to data (in this case data has to be a hash)

    $db->set_metadata('type', '0123', 'users', {paul => 'bar'});
    or
    $db->set_metadata('type', '0123', 'users.paul', 'bar');

    difference here is that the first will replace 'users',
    while the second adds the user named 'paul'

=head2 remove_metadata
    
    $bool = $db->remove_metadata(type, id, selection);

Deletes the data at selection (uses dot notation)

    $db->remove_metadata('type', '0123', 'users.paul');

=head2 find_objects

    ([ids]) = $db->find_objects(type, query);

Allows you to query for objects based on the metadata will use query
syntax similar to MongoDB.
=cut
package ModelSEED::Database;
use Moose::Role;

requires 'has_object';
requires 'get_object';
requires 'save_object';
requires 'delete_object';
requires 'get_metadata';
requires 'set_metadata';
requires 'remove_metadata';
requires 'find_objects';
1;
