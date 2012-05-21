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

=head2 has_data

    $bool = $db->has_data(ref, auth);

=head2 get_data

    $obj = $db->get_data(ref, auth);

=head2 get_data_collection

    $collection = $db->get_data_collection(ref, auth);

=head2 get_data_collection_iterator

    $iterator = $db->get_data_collection_itorator(ref, auth);

=head2 save_data

    $ref = $db->save_data(ref, data, auth);

=head2 save_data_collection

    $bool = save_data_collection(ref, collection, auth);

=head2 delete_data

    $count = $db->delete_object(ref, auth);

=head2 delete_collection

    $count = $db->delete_object(ref, auth);

=head2 find_objects

    ([ids]) = $db->find_objects(ref, query, auth);

Allows you to query for objects based on the metadata will use query
syntax similar to MongoDB.

Uses MongoDB syntax like here:
L<http://search.cpan.org/~kristina/MongoDB/lib/MongoDB/Tutorial.pod#Queries>
L<http://www.mongodb.org/display/DOCS/Advanced+Queries>

=cut
package ModelSEED::Database;
use Moose::Role;
requires 'has_data';
requires 'get_data';
requires 'get_data_collection';
requires 'get_data_collection_iterator';
requires 'save_data';
requires 'save_data_collection';

requires 'delete_data';
requires 'delete_data_collection';

requires 'find_data';


=cut
requires 'has_object';
requires 'get_object';
requires 'save_object';
requires 'delete_object';
requires 'find_objects';
=cut
1;
