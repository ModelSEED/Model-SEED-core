package ModelSEED::Database;

use Moose::Role;

=head has_object
(exists) = $db->has_object(type, id);
=cut
requires 'has_object';

=head get_object
(object) = $db->get_object(type, id);
=cut
requires 'get_object';

=head save_object
(success) = $db->save_object(type, id, object);
=cut
requires 'save_object';

=head delete_object
(success) = $db->delete_object(type, id);
=cut
requires 'delete_object';

=head get_metadata
(metadata) = $db->get_metadata(type, id, selection);

selection can be specified to return specific metadata
and uses dot notation to select inside sub-objects

ex:
    meta: {name => 'foo', users => {paul => 'bar', zedd => 'test'}}

    $db->get_metadata('type', '0123', 'users.paul');
    returns: 'bar'

    $db->get_metadata('type', '0123', 'users');
    returns: { paul => 'bar', zedd => 'test' }
=cut
requires 'get_metadata';

=head set_metadata
(success) = $db->set_metadata(type, id, selection, metadata);

selection specifies where to save metadata (uses dot notation)
if selection is undef or the empty string, will set the whole metadata to data
(in this case data has to be a hash)

ex:
    $db->set_metadata('type', '0123', 'users', {paul => 'bar'});
    or
    $db->set_metadata('type', '0123', 'users.paul', 'bar');

    difference here is that the first will replace 'users',
    while the second adds the user named 'paul'
=cut
requires 'set_metadata';

=head remove_metadata
(success) = $db->remove_metadata(type, id, selection);

deletes the data at selection (uses dot notation)

ex:
    $db->remove_metadata('type', '0123', 'users.paul');

=cut
requires 'remove_metadata';

=head find_objects
([ids]) = $db->find_objects(type, query);

allows you to query for objects based on the metadata
will use query syntax similar to mongodb
=cut
requires 'find_objects';

1;
