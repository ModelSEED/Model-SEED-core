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

=head2 Methods

=head3 has_data

    $bool = $db->has_data(ref, auth);

=head3 get_data

    $obj = $db->get_data(ref, auth);

=head3 get_data_collection

    $collection = $db->get_data_collection(ref, auth);

=head3 get_data_collection_iterator

    $iterator = $db->get_data_collection_itorator(ref, auth);

=head3 save_data

    $ref = $db->save_data(ref, data, auth);

=head3 save_data_collection

    $bool = save_data_collection(ref, collection, auth);

=head3 delete_data

    $count = $db->delete_object(ref, auth);

=head3 delete_collection

    $count = $db->delete_object(ref, auth);

=head3 find_objects

    ([ids]) = $db->find_objects(ref, query, auth);

Allows you to query for objects based on the metadata will use query
syntax similar to MongoDB.

Uses MongoDB syntax like here:
L<http://search.cpan.org/~kristina/MongoDB/lib/MongoDB/Tutorial.pod#Queries>
L<http://www.mongodb.org/display/DOCS/Advanced+Queries>

=head2 Alias Functions

These functions manage aliases, which are special pointers to
objects. These pointers have viewing permissions and can only be
moved to a different object by their owner. Alias strings have the
form of "username/arbitraryString" and are used in place of uuids
in some specific objects (biochemistry, mapping and model for now).
So a reference to a biochemistry would look like
C<biochemistry/chenry/main>.

In these functions:

=over 4

=item C<ref> is a L<ModelSEED::Reference>

=item C<auth> is a L<ModelSEED::Auth>

=item C<arbitraryString> is the free-form portion of the alias

=item C<viewerUsername> is a username

=back

=head3 create_alias

    $bool = $db->create_alias(ref, arbitraryString, auth)

=head3 add_viewer

    $bool = $db->add_viewer(ref, viewerUsername, auth)

=head3 remove_viewer

    $bool = $db->remove_viewer(ref, viewerUsername, auth)

=head3 set_public

    $bool = $db->set_public(ref, boolean, auth)

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

requires 'create_alias';
requires 'add_viewer';
requires 'remove_viewer';
requires 'set_public';


=cut
requires 'has_object';
requires 'get_object';
requires 'save_object';
requires 'delete_object';
requires 'find_objects';
=cut
1;
